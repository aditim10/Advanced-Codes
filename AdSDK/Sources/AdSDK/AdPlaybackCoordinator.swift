//
//  AdPlaybackCoordinator.swift
//  AdSDK
//
//  The public entry point that turns any ``AdContentPlayer`` into an ad-enabled
//  content player. It orchestrates the wiring between:
//    - the content player (progress + seek interception, via `AdContentPlayer`),
//    - the ``AdManager`` brain (when is a break due / how to resolve a seek),
//    - the ``AdOverlayView`` (renders the ad pod), and
//    - the ``AdSDKLogger`` (events + stream metrics).
//
//  It depends only on abstractions it owns (`AdContentPlayer`, `AdSourceResolving`,
//  `StreamMetricsCollecting`) — there is no compile-time dependency on any concrete
//  video-player implementation. The host supplies an adapter (see the app's
//  `VideoPlayerAdContentAdapter`).
//
//  Behaviour:
//    - Mid-roll: when linear playback reaches an unwatched cue, content pauses and
//      the break plays, then content resumes.
//    - Seek across an unwatched cue under `.redirect`: the break is played first,
//      then the player snaps to the viewer's original destination (re-evaluating
//      for any further crossed breaks). Under `.allowed`, the seek is honoured and
//      crossed breaks are marked consumed.
//

import UIKit
import AVFoundation

/// Where the VMAP comes from.
public enum VMAPSource: Sendable {
    case vmap(VMAP)
    case xml(String)
    case data(Data)
    case url(URL)
}

/// Everything the coordinator needs to run a content+ads session.
public struct AdPlaybackConfiguration {
    public var contentURL: URL
    public var title: String?
    public var vmapSource: VMAPSource
    public var tier: AdTier
    public var seekPolicy: SeekAdPolicy
    public var accentColor: UIColor
    public var metricsInterval: TimeInterval

    public init(contentURL: URL,
                title: String? = nil,
                vmapSource: VMAPSource,
                tier: AdTier = .adSupported,
                seekPolicy: SeekAdPolicy = .redirect,
                accentColor: UIColor = .systemYellow,
                metricsInterval: TimeInterval = 10) {
        self.contentURL = contentURL
        self.title = title
        self.vmapSource = vmapSource
        self.tier = tier
        self.seekPolicy = seekPolicy
        self.accentColor = accentColor
        self.metricsInterval = metricsInterval
    }
}

@MainActor
public final class AdPlaybackCoordinator {

    private let contentPlayer: AdContentPlayer
    private let configuration: AdPlaybackConfiguration
    private weak var logger: AdSDKLogger?

    private let sourceResolver: AdSourceResolving
    private let metricsCollector: StreamMetricsCollecting
    private let overlayFactory: (UIColor) -> AdOverlayView

    private var manager: AdManager?
    private var loadedVMAP: VMAP?
    private var contentDuration: TimeInterval = 0

    /// Ad pods resolved ahead of their cue ("ad-fetch before screen time"), keyed
    /// by break id, plus the AVURLAssets warmed for their media.
    private var prefetchedPods: [String: [PlayableAd]] = [:]
    private var warmedAssets: [URL: AVURLAsset] = [:]

    private var overlay: AdOverlayView?
    private var isPlayingAd = false
    private var pendingResume: TimeInterval?
    private var currentBreakTime: TimeInterval = 0

    private var startDate: Date?
    private var startupTime: TimeInterval = 0
    private var didRecordStartup = false
    private var metricsTimer: Timer?

    /// - Parameters:
    ///   - contentPlayer: host-supplied adapter for the real video player.
    ///   - sourceResolver: resolves VMAP ad sources to playable pods (injectable
    ///     for tests; defaults to network-backed wrapper resolution).
    ///   - metricsCollector: produces stream-metric snapshots (injectable).
    ///   - overlayFactory: builds the ad overlay (injectable for tests).
    public init(contentPlayer: AdContentPlayer,
                configuration: AdPlaybackConfiguration,
                logger: AdSDKLogger?,
                sourceResolver: AdSourceResolving = DefaultAdSourceResolver(),
                metricsCollector: StreamMetricsCollecting = StreamMetricsCollector(),
                overlayFactory: @escaping (UIColor) -> AdOverlayView = { AdOverlayView(accentColor: $0) }) {
        self.contentPlayer = contentPlayer
        self.configuration = configuration
        self.logger = logger
        self.sourceResolver = sourceResolver
        self.metricsCollector = metricsCollector
        self.overlayFactory = overlayFactory
    }

    // MARK: - Lifecycle

    /// Loads the VMAP, observes the content player, and starts content playback.
    public func start() {
        contentPlayer.adObserver = self
        startDate = Date()
        didRecordStartup = false

        Task { [weak self] in
            guard let self else { return }
            let vmap = await self.loadVMAP()
            await MainActor.run {
                self.loadedVMAP = vmap
                self.buildManagerIfReady()
            }
        }

        contentPlayer.loadContent(url: configuration.contentURL, title: configuration.title)
        startMetricsTimer()
    }

    /// Tears everything down. Call before dismissing the player.
    public func stop() {
        metricsTimer?.invalidate()
        metricsTimer = nil
        collectMetrics()
        overlay?.stop()
        overlay?.removeFromSuperview()
        overlay = nil
        isPlayingAd = false
        prefetchedPods.removeAll()
        warmedAssets.removeAll()
        contentPlayer.adObserver = nil
    }

    // MARK: - VMAP / schedule

    private func loadVMAP() async -> VMAP? {
        switch configuration.vmapSource {
        case .vmap(let vmap):
            return vmap
        case .xml(let string):
            return try? VMAPParser.parse(string: string)
        case .data(let data):
            return try? VMAPParser.parse(data: data)
        case .url(let url):
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return try? VMAPParser.parse(data: data)
        }
    }

    private func buildManagerIfReady() {
        guard manager == nil, let vmap = loadedVMAP, contentDuration > 0 else { return }
        let schedule = AdSchedule(vmap: vmap, contentDuration: contentDuration, tier: configuration.tier)
        manager = AdManager(schedule: schedule, seekPolicy: configuration.seekPolicy)
        // Surface the scheduled mid-roll cues on the player's scrubber (OTT-style).
        contentPlayer.setAdCueMarkers(schedule.breaks.map { $0.scheduledTime })
        prefetchPods()
    }

    // MARK: - Prefetch ("ad-fetch before screen time")

    /// Resolves every scheduled break's ad pod and warms its media assets *ahead*
    /// of the cue, so when a break becomes due the ad starts immediately instead of
    /// cold-loading on screen. The mediator (this coordinator) collects and holds
    /// the resolved pods; the agnostic content player is never coupled to any of it.
    private func prefetchPods() {
        guard let manager else { return }
        for adBreak in manager.schedule.breaks where prefetchedPods[adBreak.id] == nil {
            Task { [weak self] in
                guard let self else { return }
                let pod = await self.sourceResolver.resolvePod(from: adBreak.source, maxAds: adBreak.maxAds)
                await MainActor.run {
                    self.prefetchedPods[adBreak.id] = pod
                    self.warmAssets(for: pod)
                }
            }
        }
    }

    /// Kicks off `AVURLAsset` loading for each ad's media so the bytes/manifest are
    /// already in flight (or cached) by the time the overlay builds its item.
    private func warmAssets(for pod: [PlayableAd]) {
        for ad in pod where warmedAssets[ad.mediaURL] == nil {
            let asset = AVURLAsset(url: ad.mediaURL)
            warmedAssets[ad.mediaURL] = asset
            if #available(iOS 16.0, *) {
                Task { _ = try? await asset.load(.isPlayable) }
            } else {
                asset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: nil)
            }
        }
    }

    private func assetMap(for pod: [PlayableAd]) -> [URL: AVURLAsset] {
        var map: [URL: AVURLAsset] = [:]
        for ad in pod {
            if let asset = warmedAssets[ad.mediaURL] { map[ad.mediaURL] = asset }
        }
        return map
    }

    // MARK: - Break playback

    private func startBreak(_ adBreak: ScheduledAdBreak) {
        guard !isPlayingAd else { return }
        isPlayingAd = true
        currentBreakTime = adBreak.scheduledTime
        manager?.markBreakWatched(id: adBreak.id)   // optimistic: won't re-trigger
        contentPlayer.pauseContent()
        showOverlay()

        // Use the pod fetched ahead of time when available; otherwise resolve now.
        if let pod = prefetchedPods[adBreak.id] {
            playResolvedPod(pod, for: adBreak)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let ads = await self.sourceResolver.resolvePod(from: adBreak.source, maxAds: adBreak.maxAds)
            await MainActor.run {
                guard self.isPlayingAd else { return }
                self.warmAssets(for: ads)
                self.playResolvedPod(ads, for: adBreak)
            }
        }
    }

    private func playResolvedPod(_ ads: [PlayableAd], for adBreak: ScheduledAdBreak) {
        guard isPlayingAd else { return }
        if ads.isEmpty {
            logger?.adSDK(didEmit: .adError(adID: nil, message: "No ads resolved for break \(adBreak.id)"))
            finishBreak()
        } else {
            overlay?.playBreak(id: adBreak.id, ads: ads, preloadedAssets: assetMap(for: ads))
        }
    }

    private func showOverlay() {
        guard overlay == nil else { return }
        let anchor = contentPlayer.adContentView
        guard let host = anchor.superview else { return }
        let overlay = overlayFactory(configuration.accentColor)
        overlay.delegate = self
        overlay.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: anchor.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: anchor.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: anchor.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: anchor.bottomAnchor),
        ])
        self.overlay = overlay
    }

    private func finishBreak() {
        overlay?.stop()
        overlay?.removeFromSuperview()
        overlay = nil
        isPlayingAd = false
        resumeAfterBreak()
    }

    /// Resumes content after a break. For a redirect seek, re-evaluates whether
    /// any further unwatched break is crossed before the destination; otherwise
    /// snaps to the destination. For a normal mid-roll, just resumes playback.
    private func resumeAfterBreak() {
        guard let resume = pendingResume, let manager else {
            contentPlayer.playContent()
            return
        }
        let decision = manager.resolveSeek(from: currentBreakTime, to: resume)
        switch decision {
        case .seek(let to):
            pendingResume = nil
            contentPlayer.seekContent(to: to)
            contentPlayer.playContent()
        case .playBreak(let id, _):
            if let next = manager.adBreak(id: id) {
                startBreak(next)
            } else {
                pendingResume = nil
                contentPlayer.seekContent(to: resume)
                contentPlayer.playContent()
            }
        }
    }

    // MARK: - Metrics

    private func startMetricsTimer() {
        metricsTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: configuration.metricsInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.collectMetrics() }
        }
        metricsTimer = timer
    }

    private func collectMetrics() {
        guard let item = contentPlayer.currentPlayerItem else { return }
        let metrics = metricsCollector.snapshot(for: item, kind: .content, startupTime: startupTime)
        logger?.adSDK(didCollect: metrics)
    }
}

// MARK: - AdContentPlayerObserver (content events + seek interception)

extension AdPlaybackCoordinator: AdContentPlayerObserver {

    public func contentPlayerDidBecomeReady(duration: TimeInterval) {
        contentDuration = duration
        buildManagerIfReady()
    }

    public func contentPlayerDidProgress(to time: TimeInterval, duration: TimeInterval) {
        if !isPlayingAd, let due = manager?.dueBreak(at: time) {
            startBreak(due)
        }
    }

    public func contentPlayerDidStartPlaying() {
        if !didRecordStartup, let startDate {
            startupTime = Date().timeIntervalSince(startDate)
            didRecordStartup = true
        }
    }

    public func contentPlayerDidFinish() {
        collectMetrics()
        metricsTimer?.invalidate()
        metricsTimer = nil
    }

    public func contentPlayer(shouldSeekTo target: TimeInterval) -> Bool {
        guard let manager, !isPlayingAd else { return true }
        let decision = manager.resolveSeek(from: contentPlayer.currentTime, to: target)
        switch decision {
        case .seek:
            return true
        case .playBreak(let id, let resumeAt):
            guard let adBreak = manager.adBreak(id: id) else { return true }
            pendingResume = resumeAt
            startBreak(adBreak)
            return false
        }
    }
}

// MARK: - AdOverlayViewDelegate

extension AdPlaybackCoordinator: AdOverlayViewDelegate {

    public func adOverlay(_ overlay: AdOverlayView, didEmit event: AdEvent) {
        logger?.adSDK(didEmit: event)
    }

    public func adOverlay(_ overlay: AdOverlayView, didFinishBreak breakID: String) {
        finishBreak()
    }

    public func adOverlay(_ overlay: AdOverlayView, didRequestOpen url: URL) {
        UIApplication.shared.open(url)
    }
}
