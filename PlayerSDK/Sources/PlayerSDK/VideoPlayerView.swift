//
//  VideoPlayerView.swift
//  PlayerSDK
//
//  The public host view the client embeds ("parent UI view to set"). It owns an
//  `AVPlayer`, renders it via an `AVPlayerLayer`, draws the custom controls on
//  top, and reports everything back through `VideoPlayerDelegate`.
//
//  Typical use:
//
//      let player = VideoPlayerView()
//      player.delegate = self
//      view.addSubview(player)            // pin with Auto Layout
//      player.load(VideoPlayerConfiguration(url: trailerURL, title: "Frieren"))
//

import UIKit
import AVFoundation

/// A backing view whose root layer *is* an `AVPlayerLayer`, so the video resizes
/// automatically with the view (no manual frame juggling).
private final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

public final class VideoPlayerView: UIView {

    // MARK: - Public API

    /// Receives all player events. See ``VideoPlayerDelegate``.
    public weak var delegate: VideoPlayerDelegate?

    /// The current lifecycle state. Every change is also pushed to the delegate.
    public private(set) var state: VideoPlayerState = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.videoPlayer(self, didChangeState: state)
        }
    }

    /// Current playback position in seconds.
    public var currentTime: TimeInterval {
        guard let t = player.currentItem?.currentTime().seconds, t.isFinite else { return 0 }
        return t
    }

    /// Total duration in seconds (0 until known).
    public private(set) var duration: TimeInterval = 0

    /// Whether audio is currently muted.
    public var isMuted: Bool { player.isMuted }

    // MARK: - Private state

    private let player = AVPlayer()
    private let layerView = PlayerLayerView()
    private lazy var controls = VideoPlayerControlsView(
        accentColor: configuration?.accentColor ?? .systemPurple,
        skipSeconds: Int(configuration?.skipInterval ?? 10)
    )

    private var configuration: VideoPlayerConfiguration?
    private var timeObserver: Any?
    private var observations: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?

    private var controlsVisible = true
    private var hideControlsWorkItem: DispatchWorkItem?

    // Fullscreen bookkeeping
    public private(set) var isFullscreen = false
    private weak var originalSuperview: UIView?
    private var savedConstraints: [NSLayoutConstraint] = []
    private var originalFrameInWindow: CGRect = .zero

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
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

        wireControls()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleControlsVisibility)))
        observePlayer()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        observations.forEach { $0.invalidate() }
    }

    // MARK: - Loading

    /// Loads `configuration` and (if `autoPlay`) begins playback once ready.
    public func load(_ configuration: VideoPlayerConfiguration) {
        self.configuration = configuration
        controls.setTitle(configuration.title)

        // Play audio even when the hardware mute switch is on (movie playback),
        // otherwise trailers appear silent on a silenced device. Done off the main
        // thread because `setActive` can briefly block.
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        let item = AVPlayerItem(url: configuration.url)
        observeItem(item)
        player.replaceCurrentItem(with: item)
        player.isMuted = configuration.startsMuted
        controls.setVolume(player.volume, isMuted: player.isMuted)

        duration = 0
        state = .loading
        controls.setBuffering(true)
    }

    // MARK: - Playback controls (public)

    public func play() {
        player.play()
        scheduleControlsAutoHide()
    }

    public func pause() {
        player.pause()
    }

    public func togglePlayPause() {
        player.timeControlStatus == .paused ? play() : pause()
    }

    /// Seeks to an absolute `time` (seconds), clamped to the item bounds.
    public func seek(to time: TimeInterval) {
        let target = VideoTime.clamp(time, duration: duration)
        let cmTime = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            self.delegate?.videoPlayer(self, didSeekTo: target)
        }
    }

    /// Jumps forward by the configured skip interval (default 10s).
    public func skipForward() {
        let offset = configuration?.skipInterval ?? 10
        seek(to: VideoTime.target(from: currentTime, offset: offset, duration: duration))
    }

    /// Jumps backward by the configured skip interval (default 10s).
    public func skipBackward() {
        let offset = configuration?.skipInterval ?? 10
        seek(to: VideoTime.target(from: currentTime, offset: -offset, duration: duration))
    }

    /// Sets the audio volume (`0...1`). Unmutes if currently muted.
    public func setVolume(_ volume: Float) {
        let clamped = min(max(volume, 0), 1)
        player.volume = clamped
        if clamped > 0 { player.isMuted = false }
        controls.setVolume(clamped, isMuted: player.isMuted)
        delegate?.videoPlayer(self, didChangeVolume: clamped, isMuted: player.isMuted)
    }

    /// Toggles mute on/off.
    public func toggleMute() {
        player.isMuted.toggle()
        controls.setVolume(player.volume, isMuted: player.isMuted)
        delegate?.videoPlayer(self, didChangeVolume: player.volume, isMuted: player.isMuted)
    }

    // MARK: - Fullscreen (public)

    public func toggleFullscreen() {
        isFullscreen ? exitFullscreen() : enterFullscreen()
    }

    public func enterFullscreen() {
        guard !isFullscreen, let window = keyWindow else { return }
        originalSuperview = superview
        originalFrameInWindow = convert(bounds, to: window)
        savedConstraints = (superview?.constraints ?? []).filter {
            ($0.firstItem === self) || ($0.secondItem === self)
        }
        NSLayoutConstraint.deactivate(savedConstraints)

        translatesAutoresizingMaskIntoConstraints = true
        frame = originalFrameInWindow
        window.addSubview(self)
        isFullscreen = true
        controls.setFullscreen(true)

        UIView.animate(withDuration: 0.3) { self.frame = window.bounds }
        delegate?.videoPlayer(self, didToggleFullscreen: true)
    }

    public func exitFullscreen() {
        guard isFullscreen, let originalSuperview else { return }
        controls.setFullscreen(false)

        UIView.animate(withDuration: 0.3, animations: {
            self.frame = self.originalFrameInWindow
        }, completion: { _ in
            self.removeFromSuperview()
            self.translatesAutoresizingMaskIntoConstraints = false
            originalSuperview.addSubview(self)
            NSLayoutConstraint.activate(self.savedConstraints)
            self.savedConstraints = []
            self.isFullscreen = false
        })
        delegate?.videoPlayer(self, didToggleFullscreen: false)
    }

    // MARK: - Controls wiring

    private func wireControls() {
        controls.onPlayPause = { [weak self] in self?.togglePlayPause() }
        controls.onSkipBackward = { [weak self] in self?.skipBackward() }
        controls.onSkipForward = { [weak self] in self?.skipForward() }
        controls.onScrubBegan = { [weak self] in self?.cancelControlsAutoHide() }
        controls.onScrub = { [weak self] progress in
            guard let self else { return }
            // Live time label update while dragging (no actual seek yet).
            self.controls.setProgress(current: Double(progress) * self.duration, duration: self.duration)
        }
        controls.onScrubEnded = { [weak self] progress in
            guard let self else { return }
            self.seek(to: Double(progress) * self.duration)
            self.scheduleControlsAutoHide()
        }
        controls.onToggleMute = { [weak self] in self?.toggleMute() }
        controls.onVolumeChange = { [weak self] vol in self?.setVolume(vol) }
        controls.onToggleFullscreen = { [weak self] in self?.toggleFullscreen() }
        controls.onClose = { [weak self] in self?.handleClose() }
    }

    /// Closure invoked when the user taps the close button (set by the host VC).
    public var onRequestClose: (() -> Void)?
    private func handleClose() {
        if isFullscreen { exitFullscreen() } else { onRequestClose?() }
    }

    // MARK: - Observation

    private func observePlayer() {
        // Periodic progress (~3 fps) for the scrubber + delegate.
        let interval = CMTime(seconds: 0.3, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = time.seconds.isFinite ? time.seconds : 0
            self.controls.setProgress(current: current, duration: self.duration)
            self.delegate?.videoPlayer(self, didProgressTo: current, duration: self.duration)
        }

        // Play / pause transitions. KVO change handlers are delivered on an
        // arbitrary (often background) thread, so every UIKit/delegate touch is
        // hopped to the main thread — otherwise the Main Thread Checker pauses the
        // app under the debugger (which looks exactly like a freeze).
        observations.append(
            player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                let status = player.timeControlStatus
                Self.onMain {
                    guard let self else { return }
                    switch status {
                    case .playing:
                        self.state = .playing
                        self.controls.setPlaying(true)
                        self.controls.setBuffering(false)
                        self.delegate?.videoPlayerDidPlay(self)
                    case .paused:
                        if self.state != .ended { self.state = .paused }
                        self.controls.setPlaying(false)
                        self.delegate?.videoPlayerDidPause(self)
                    case .waitingToPlayAtSpecifiedRate:
                        self.controls.setBuffering(true)
                    @unknown default:
                        break
                    }
                }
            }
        )
    }

    private func observeItem(_ item: AVPlayerItem) {
        // Tear down any previous item's end observer.
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }

        observations.append(
            item.observe(\.status, options: [.new]) { [weak self] item, _ in
                let status = item.status
                let itemDuration = item.duration.seconds
                let itemError = item.error
                // KVO fires off the main thread — marshal UI/delegate work to main.
                Self.onMain {
                    guard let self else { return }
                    switch status {
                    case .readyToPlay:
                        self.duration = itemDuration.isFinite ? itemDuration : 0
                        self.state = .readyToPlay
                        self.controls.setBuffering(false)
                        self.delegate?.videoPlayer(self, didBecomeReadyWithDuration: self.duration)
                        if self.configuration?.autoPlay == true { self.play() }
                    case .failed:
                        let reason = itemError?.localizedDescription ?? "Unknown playback error"
                        self.state = .failed(reason)
                        self.controls.setBuffering(false)
                        self.delegate?.videoPlayer(self, didFailWithError:
                            itemError ?? NSError(domain: "PlayerSDK", code: -1,
                                                  userInfo: [NSLocalizedDescriptionKey: reason]))
                    default:
                        break
                    }
                }
            }
        )

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.configuration?.loops == true {
                self.seek(to: 0)
                self.play()
            } else {
                self.state = .ended
                self.controls.setPlaying(false)
                self.delegate?.videoPlayerDidFinish(self)
            }
        }
    }

    // MARK: - Controls visibility

    @objc private func toggleControlsVisibility() {
        controlsVisible ? hideControls() : showControls()
    }

    private func showControls() {
        controlsVisible = true
        UIView.animate(withDuration: 0.2) { self.controls.alpha = 1 }
        scheduleControlsAutoHide()
    }

    private func hideControls() {
        controlsVisible = false
        cancelControlsAutoHide()
        UIView.animate(withDuration: 0.2) { self.controls.alpha = 0 }
    }

    private func scheduleControlsAutoHide() {
        cancelControlsAutoHide()
        guard player.timeControlStatus == .playing else { return }
        let work = DispatchWorkItem { [weak self] in self?.hideControls() }
        hideControlsWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func cancelControlsAutoHide() {
        hideControlsWorkItem?.cancel()
        hideControlsWorkItem = nil
    }

    // MARK: - Helpers

    /// Runs `work` on the main thread immediately if already there, otherwise
    /// hops to it. Used to make KVO callbacks (delivered on background threads)
    /// safe for UIKit/delegate work.
    private static func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private var keyWindow: UIWindow? {
        window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
