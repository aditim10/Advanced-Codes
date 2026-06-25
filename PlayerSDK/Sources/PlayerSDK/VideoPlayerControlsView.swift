//
//  VideoPlayerControlsView.swift
//  PlayerSDK
//
//  The translucent controls overlay drawn on top of the video: a center
//  play/pause with ±skip buttons, a bottom scrubber with time labels, and a
//  trailing row with volume/mute + fullscreen. It is purely presentational — it
//  reports user intent through closures and is updated via the `set*` methods by
//  `VideoPlayerView`. It knows nothing about AVFoundation.
//

import UIKit

final class VideoPlayerControlsView: UIView {

    // MARK: User-intent callbacks (wired by VideoPlayerView)
    var onPlayPause: (() -> Void)?
    var onSkipBackward: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onScrubBegan: (() -> Void)?
    var onScrub: ((Float) -> Void)?   // 0...1
    var onScrubEnded: ((Float) -> Void)?   // 0...1
    var onToggleMute: (() -> Void)?
    var onVolumeChange: ((Float) -> Void)?   // 0...1
    var onToggleFullscreen: (() -> Void)?
    var onClose: (() -> Void)?

    // MARK: Subviews
    private let scrim = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private let playPauseButton = UIButton(type: .system)
    private let skipBackButton = UIButton(type: .system)
    private let skipFwdButton = UIButton(type: .system)
    private let bufferingSpinner = UIActivityIndicatorView(style: .large)

    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let scrubber = UISlider()

    /// Transparent overlay pinned over the scrubber on which ad cue ticks are drawn
    /// (like OTT timelines). Non-interactive so it never blocks scrubbing.
    private let cueOverlay = UIView()

    /// Absolute cue times (seconds) to mark on the scrubber, plus the duration they
    /// are positioned against. Markers re-layout whenever either changes.
    private var cueTimes: [TimeInterval] = []
    private var cueDuration: TimeInterval = 0

    /// Tint for ad cue ticks. Yellow reads as "ad break" on most OTT players.
    var cueMarkerColor: UIColor = .systemYellow

    private let muteButton = UIButton(type: .system)
    private let volumeSlider = UISlider()
    private let fullscreenButton = UIButton(type: .system)

    private let accent: UIColor
    private let skipSeconds: Int

    // MARK: Init
    init(accentColor: UIColor, skipSeconds: Int) {
        self.accent = accentColor
        self.skipSeconds = skipSeconds
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Setup
    private func setup() {
        // Dim scrim so white controls stay legible over bright frames.
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrim)

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1

        configureIconButton(closeButton, systemName: "xmark")
        configureIconButton(playPauseButton, systemName: "play.fill", pointSize: 34)
        configureIconButton(skipBackButton, systemName: "gobackward.\(skipSeconds)", pointSize: 24)
        configureIconButton(skipFwdButton, systemName: "goforward.\(skipSeconds)", pointSize: 24)
        configureIconButton(muteButton, systemName: "speaker.wave.2.fill")
        configureIconButton(fullscreenButton, systemName: "arrow.up.left.and.arrow.down.right")

        bufferingSpinner.color = .white
        bufferingSpinner.hidesWhenStopped = true
        bufferingSpinner.translatesAutoresizingMaskIntoConstraints = false

        [currentTimeLabel, durationLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            $0.textColor = .white
            $0.text = "0:00"
        }

        scrubber.setMinimumTrackImage(Self.trackImage(color: accent), for: .normal)
        scrubber.setMaximumTrackImage(Self.trackImage(color: UIColor.white.withAlphaComponent(0.22)), for: .normal)
        scrubber.setThumbImage(Self.thumbImage(diameter: 14), for: .normal)
        scrubber.setThumbImage(Self.thumbImage(diameter: 18), for: .highlighted)
        scrubber.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        volumeSlider.setMinimumTrackImage(Self.trackImage(color: accent), for: .normal)
        volumeSlider.setMaximumTrackImage(Self.trackImage(color: UIColor.white.withAlphaComponent(0.22)), for: .normal)
        volumeSlider.setThumbImage(Self.thumbImage(diameter: 12), for: .normal)
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false

        // Center transport stack: ⏪  ⏯  ⏩
        let transport = UIStackView(arrangedSubviews: [skipBackButton, playPauseButton, skipFwdButton])
        transport.axis = .horizontal
        transport.alignment = .center
        transport.distribution = .equalSpacing
        transport.spacing = 36
        transport.translatesAutoresizingMaskIntoConstraints = false

        // Bottom scrubber row: 0:00  [======]  3:21
        let scrubberRow = UIStackView(arrangedSubviews: [currentTimeLabel, scrubber, durationLabel])
        scrubberRow.axis = .horizontal
        scrubberRow.alignment = .center
        scrubberRow.spacing = 8
        scrubberRow.translatesAutoresizingMaskIntoConstraints = false

        // Trailing row under the scrubber: 🔊 [vol]      ⛶
        let volumeStack = UIStackView(arrangedSubviews: [muteButton, volumeSlider])
        volumeStack.axis = .horizontal
        volumeStack.alignment = .center
        volumeStack.spacing = 6
        volumeStack.translatesAutoresizingMaskIntoConstraints = false

        let bottomRow = UIStackView(arrangedSubviews: [volumeStack, UIView(), fullscreenButton])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        cueOverlay.translatesAutoresizingMaskIntoConstraints = false
        cueOverlay.isUserInteractionEnabled = false
        cueOverlay.backgroundColor = .clear

        addSubview(titleLabel)
        addSubview(closeButton)
        addSubview(transport)
        addSubview(bufferingSpinner)
        addSubview(scrubberRow)
        addSubview(bottomRow)
        // Above the slider so ticks sit on top of the track.
        addSubview(cueOverlay)

        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: topAnchor),
            scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12),

            transport.centerXAnchor.constraint(equalTo: centerXAnchor),
            transport.centerYAnchor.constraint(equalTo: centerYAnchor),

            bufferingSpinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            bufferingSpinner.centerYAnchor.constraint(equalTo: centerYAnchor),

            volumeSlider.widthAnchor.constraint(equalToConstant: 90),

            scrubberRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scrubberRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            // Overlay tracks the slider exactly so tick x-positions map 1:1.
            cueOverlay.leadingAnchor.constraint(equalTo: scrubber.leadingAnchor),
            cueOverlay.trailingAnchor.constraint(equalTo: scrubber.trailingAnchor),
            cueOverlay.topAnchor.constraint(equalTo: scrubber.topAnchor),
            cueOverlay.bottomAnchor.constraint(equalTo: scrubber.bottomAnchor),
            bottomRow.topAnchor.constraint(equalTo: scrubberRow.bottomAnchor, constant: 6),
            bottomRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bottomRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bottomRow.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])

        // Targets
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        skipBackButton.addTarget(self, action: #selector(skipBackTapped), for: .touchUpInside)
        skipFwdButton.addTarget(self, action: #selector(skipFwdTapped), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)

        scrubber.addTarget(self, action: #selector(scrubTouchDown), for: .touchDown)
        scrubber.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        scrubber.addTarget(self, action: #selector(scrubTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
    }

    /// A small circular slider thumb with a soft shadow. Much clearer than the
    /// oversized default thumb, so the scrubber position stays readable.
    private static func thumbImage(diameter: CGFloat) -> UIImage {
        let pad: CGFloat = 3   // room for the drop shadow
        let size = CGSize(width: diameter + pad * 2, height: diameter + pad * 2)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(x: pad, y: pad, width: diameter, height: diameter)
            c.setShadow(offset: CGSize(width: 0, height: 1), blur: 3,
                        color: UIColor.black.withAlphaComponent(0.55).cgColor)
            UIColor.white.setFill()
            c.fillEllipse(in: rect)
        }
    }

    /// A thin rounded (capsule) track segment, resizable along its width so the
    /// played/remaining portions read as a clean OTT-style bar.
    private static func trackImage(color: UIColor, height: CGFloat = 4) -> UIImage {
        let size = CGSize(width: height + 1, height: height)
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size),
                         cornerRadius: height / 2).fill()
        }
        return img.resizableImage(
            withCapInsets: UIEdgeInsets(top: 0, left: height / 2, bottom: 0, right: height / 2),
            resizingMode: .stretch)
    }

    private func configureIconButton(_ button: UIButton, systemName: String, pointSize: CGFloat = 18) {
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - State updates (called by VideoPlayerView)

    func setTitle(_ title: String?) {
        titleLabel.text = title
        titleLabel.isHidden = (title?.isEmpty ?? true)
    }

    func setPlaying(_ isPlaying: Bool) {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        playPauseButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    func setBuffering(_ isBuffering: Bool) {
        isBuffering ? bufferingSpinner.startAnimating() : bufferingSpinner.stopAnimating()
        playPauseButton.isHidden = isBuffering
    }

    /// Updates the scrubber + labels. Ignored while the user is actively scrubbing
    /// (so we don't fight their finger) or while a seek is in flight (so the thumb
    /// doesn't snap back to the old position before the seek lands).
    func setProgress(current: TimeInterval, duration: TimeInterval) {
        currentTimeLabel.text = VideoTime.formatted(current)
        durationLabel.text = VideoTime.formatted(duration)
        if !isScrubbing && !isSeeking {
            scrubber.value = VideoTime.progress(current: current, duration: duration)
        }
        // Reposition cue ticks once the duration they map against becomes known.
        if duration != cueDuration {
            cueDuration = duration
            layoutCueMarkers()
        }
    }

    /// Sets the ad cue ticks shown on the scrubber (absolute times in seconds).
    /// Positions are resolved against the latest known duration.
    func setCueMarkers(_ times: [TimeInterval]) {
        cueTimes = times
        layoutCueMarkers()
    }

    /// Freezes scrubber updates while a seek resolves, keeping the thumb at the
    /// position the user picked instead of letting periodic progress snap it back.
    func setSeeking(_ seeking: Bool) {
        isSeeking = seeking
    }

    func setVolume(_ volume: Float, isMuted: Bool) {
        volumeSlider.value = isMuted ? 0 : volume
        let name = isMuted || volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        muteButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    func setFullscreen(_ isFullscreen: Bool) {
        let name = isFullscreen
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        fullscreenButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    // MARK: - Cue markers

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutCueMarkers()
    }

    /// Draws a thin vertical tick over the slider track for each cue time. Rebuilt
    /// on every layout pass / data change so it stays correct across rotation and
    /// size changes.
    private func layoutCueMarkers() {
        cueOverlay.subviews.forEach { $0.removeFromSuperview() }
        guard cueDuration > 0, !cueTimes.isEmpty else { return }

        // Map cue x-positions onto the slider's actual track rect (insets for the
        // thumb), so a tick lines up with where the thumb sits at that time.
        let track = scrubber.trackRect(forBounds: scrubber.bounds)
        let markerWidth: CGFloat = 3
        let markerHeight = max(track.height + 6, 9)

        for time in cueTimes where time > 0 && time < cueDuration {
            let fraction = CGFloat(min(max(time / cueDuration, 0), 1))
            let centerX = track.minX + fraction * track.width
            let tick = UIView(frame: CGRect(
                x: centerX - markerWidth / 2,
                y: track.midY - markerHeight / 2,
                width: markerWidth,
                height: markerHeight))
            tick.backgroundColor = cueMarkerColor
            tick.layer.cornerRadius = markerWidth / 2
            tick.layer.borderWidth = 0.5
            tick.layer.borderColor = UIColor.black.withAlphaComponent(0.35).cgColor
            cueOverlay.addSubview(tick)
        }
    }

    // MARK: - Actions
    private var isScrubbing = false
    private var isSeeking = false

    @objc private func closeTapped() { onClose?() }
    @objc private func playPauseTapped() { onPlayPause?() }
    @objc private func skipBackTapped() { onSkipBackward?() }
    @objc private func skipFwdTapped() { onSkipForward?() }
    @objc private func muteTapped() { onToggleMute?() }
    @objc private func fullscreenTapped() { onToggleFullscreen?() }

    @objc private func scrubTouchDown() { isScrubbing = true; onScrubBegan?() }
    @objc private func scrubChanged() { onScrub?(scrubber.value) }
    @objc private func scrubTouchUp() { isScrubbing = false; onScrubEnded?(scrubber.value) }
    @objc private func volumeChanged() { onVolumeChange?(volumeSlider.value) }
}
