//
//  AdOverlayView.swift
//  AdSDK
//
//  Renders an ad break on its own `AVPlayer` (independent of the content player so
//  content buffering is untouched), drawing ``AdControlsView`` on top. It plays a
//  pod of ``PlayableAd``s sequentially, fires the matching VAST beacons through
//  ``AdTracker``, computes quartiles, and surfaces high-level ``AdEvent``s to its
//  delegate. The host shows/hides it over the content player region.
//

import UIKit
import AVFoundation

public protocol AdOverlayViewDelegate: AnyObject {
    func adOverlay(_ overlay: AdOverlayView, didEmit event: AdEvent)
    func adOverlay(_ overlay: AdOverlayView, didFinishBreak breakID: String)
    /// Asked to open an ad clickthrough URL (host decides how, e.g. SafariVC).
    func adOverlay(_ overlay: AdOverlayView, didRequestOpen url: URL)
}

public extension AdOverlayViewDelegate {
    func adOverlay(_ overlay: AdOverlayView, didRequestOpen url: URL) {
        UIApplication.shared.open(url)
    }
}

/// A layer-backed view whose root layer is an `AVPlayerLayer`.
private final class AdPlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

public final class AdOverlayView: UIView {

    public weak var delegate: AdOverlayViewDelegate?

    /// The current ad item, exposed for stream-metrics collection.
    public var currentAdItem: AVPlayerItem? { player.currentItem }

    // MARK: - Private state

    private let player = AVPlayer()
    private let layerView = AdPlayerLayerView()
    private let controls: AdControlsView
    private let tracker: AdTracking

    private var breakID: String = ""
    private var ads: [PlayableAd] = []
    private var index = 0

    /// Assets warmed up ahead of time by the coordinator, keyed by media URL. When
    /// present the player item is built from the (already-loading) asset so the ad
    /// starts near-instantly instead of cold-loading at the cue.
    private var preloadedAssets: [URL: AVURLAsset] = [:]

    private var currentAd: PlayableAd? { ads.indices.contains(index) ? ads[index] : nil }
    private var adDuration: TimeInterval = 0
    private var hasStarted = false
    private var lastProgress: TimeInterval = 0
    private var firedQuartiles: Set<AdQuartile> = []

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    // MARK: - Init

    public init(accentColor: UIColor = .systemYellow, tracker: AdTracking = AdTracker()) {
        self.controls = AdControlsView(accentColor: accentColor)
        self.tracker = tracker
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        self.controls = AdControlsView(accentColor: .systemYellow)
        self.tracker = AdTracker()
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .black
        layerView.player = player
        layerView.translatesAutoresizingMaskIntoConstraints = false
        controls.translatesAutoresizingMaskIntoConstraints = false

        addSubview(layerView)
        addSubview(controls)
        NSLayoutConstraint.activate([
            layerView.topAnchor.constraint(equalTo: topAnchor),
            layerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            layerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            layerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            controls.topAnchor.constraint(equalTo: topAnchor),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        controls.onSkip = { [weak self] in self?.skipCurrentAd() }
        controls.onLearnMore = { [weak self] in self?.openClickThrough() }

        let observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            self?.handleProgress(time.seconds)
        }
        timeObserver = observer
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObservation?.invalidate()
    }

    // MARK: - Public API

    /// Starts playing the given ad pod. The overlay should already be visible.
    /// `preloadedAssets` (optional) lets the coordinator hand over assets it warmed
    /// ahead of the cue so playback starts immediately.
    public func playBreak(id: String, ads: [PlayableAd], preloadedAssets: [URL: AVURLAsset] = [:]) {
        guard !ads.isEmpty else {
            delegate?.adOverlay(self, didEmit: .adError(adID: nil, message: "Empty ad break"))
            delegate?.adOverlay(self, didFinishBreak: id)
            return
        }
        breakID = id
        self.ads = ads
        self.preloadedAssets = preloadedAssets
        index = 0
        emit(.breakStarted(breakID: id, adCount: ads.count))
        startCurrentAd()
    }

    /// Stops playback and tears down the current ad item (does not emit completion).
    public func stop() {
        player.pause()
        teardownItemObservers()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: - Ad lifecycle

    private func startCurrentAd() {
        guard let ad = currentAd else { finishBreak(); return }

        hasStarted = false
        lastProgress = 0
        adDuration = ad.duration ?? 0
        firedQuartiles = []
        controls.configure(adIndex: index, count: ads.count, isSkippable: ad.isSkippable)
        controls.setLearnMoreVisible(ad.clickThrough != nil)
        controls.setCountdown(remaining: adDuration)
        controls.setProgress(current: 0, duration: max(adDuration, 1))
        controls.setSkip(enabled: false, secondsUntilSkippable: Int((ad.skipOffset ?? 0).rounded(.up)))

        let item: AVPlayerItem
        if let warmed = preloadedAssets[ad.mediaURL] {
            item = AVPlayerItem(asset: warmed)
        } else {
            item = AVPlayerItem(url: ad.mediaURL)
        }
        observeItem(item)
        player.replaceCurrentItem(with: item)
        player.isMuted = false
        player.play()
    }

    private func handleAdStartedIfNeeded() {
        guard !hasStarted, let ad = currentAd else { return }
        hasStarted = true
        if adDuration <= 0 {
            let itemDuration = player.currentItem?.duration.seconds ?? 0
            adDuration = itemDuration.isFinite ? itemDuration : 0
        }
        tracker.impression(for: ad)
        tracker.track(.creativeView, for: ad)
        tracker.track(.start, for: ad)
        emit(.adStarted(adID: ad.id, title: ad.title, index: index, count: ads.count))
        markQuartile(.start, for: ad)
    }

    private func handleProgress(_ rawCurrent: TimeInterval) {
        guard hasStarted, let ad = currentAd else { return }
        let current = rawCurrent.isFinite ? rawCurrent : 0
        let duration = adDuration > 0 ? adDuration : current

        controls.setProgress(current: current, duration: max(duration, 1))
        controls.setCountdown(remaining: max(0, duration - current))
        updateSkipState(for: ad, current: current)

        if duration > 0 {
            let fraction = current / duration
            if fraction >= 0.25 { markQuartile(.firstQuartile, for: ad) }
            if fraction >= 0.50 { markQuartile(.midpoint, for: ad) }
            if fraction >= 0.75 { markQuartile(.thirdQuartile, for: ad) }
        }
        tracker.fireProgress(for: ad, previous: lastProgress, current: current)
        lastProgress = current
        emit(.adProgress(adID: ad.id, time: current, duration: duration))

        // Ad creatives are sourced from long-form sample streams, so the VAST-
        // declared <Duration> is authoritative: stop the ad at that point rather
        // than playing the whole underlying film.
        if let declared = currentAd?.duration, declared > 0,
           current >= declared, !firedQuartiles.contains(.complete) {
            adDidComplete()
        }
    }

    private func updateSkipState(for ad: PlayableAd, current: TimeInterval) {
        guard let skipOffset = ad.skipOffset else { return }
        if current >= skipOffset {
            controls.setSkip(enabled: true, secondsUntilSkippable: 0)
        } else {
            controls.setSkip(enabled: false, secondsUntilSkippable: Int((skipOffset - current).rounded(.up)))
        }
    }

    private func markQuartile(_ quartile: AdQuartile, for ad: PlayableAd) {
        guard !firedQuartiles.contains(quartile) else { return }
        firedQuartiles.insert(quartile)
        switch quartile {
        case .start:         break // start beacon already fired in handleAdStartedIfNeeded
        case .firstQuartile: tracker.track(.firstQuartile, for: ad)
        case .midpoint:      tracker.track(.midpoint, for: ad)
        case .thirdQuartile: tracker.track(.thirdQuartile, for: ad)
        case .complete:      tracker.track(.complete, for: ad)
        }
        emit(.quartile(adID: ad.id, quartile: quartile))
    }

    private func adDidComplete() {
        guard let ad = currentAd else { return }
        markQuartile(.complete, for: ad)
        emit(.adCompleted(adID: ad.id))
        advance()
    }

    private func skipCurrentAd() {
        guard let ad = currentAd else { return }
        tracker.track(.skip, for: ad)
        emit(.adSkipped(adID: ad.id))
        advance()
    }

    private func advance() {
        teardownItemObservers()
        index += 1
        startCurrentAd()
    }

    private func finishBreak() {
        player.pause()
        teardownItemObservers()
        player.replaceCurrentItem(with: nil)
        emit(.breakCompleted(breakID: breakID))
        delegate?.adOverlay(self, didFinishBreak: breakID)
    }

    private func openClickThrough() {
        guard let ad = currentAd, let url = ad.clickThrough else { return }
        tracker.clickTracking(for: ad)
        emit(.adClicked(adID: ad.id, url: url))
        delegate?.adOverlay(self, didRequestOpen: url)
    }

    // MARK: - Observation

    private func observeItem(_ item: AVPlayerItem) {
        teardownItemObservers()

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let itemError = item.error
            Self.onMain {
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    // Only adopt the real item duration when VAST didn't declare one.
                    // Our sample creatives are long-form streams capped to the VAST
                    // <Duration>, so the declared value must win when present.
                    if self.adDuration <= 0 {
                        let itemDuration = item.duration.seconds
                        if itemDuration.isFinite, itemDuration > 0 {
                            self.adDuration = itemDuration
                        }
                    }
                    self.handleAdStartedIfNeeded()
                case .failed:
                    let message = itemError?.localizedDescription ?? "Ad failed to load"
                    if let ad = self.currentAd { self.tracker.error(for: ad) }
                    self.emit(.adError(adID: self.currentAd?.id, message: message))
                    self.advance()   // skip the broken ad, keep the break flowing
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.adDidComplete()
        }
    }

    private func teardownItemObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func emit(_ event: AdEvent) {
        delegate?.adOverlay(self, didEmit: event)
    }

    private static func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
