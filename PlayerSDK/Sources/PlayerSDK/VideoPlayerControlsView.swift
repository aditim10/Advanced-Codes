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

        scrubber.minimumTrackTintColor = accent
        scrubber.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.4)
        scrubber.thumbTintColor = .white
        scrubber.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        volumeSlider.minimumTrackTintColor = accent
        volumeSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.4)
        volumeSlider.thumbTintColor = .white
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

        addSubview(titleLabel)
        addSubview(closeButton)
        addSubview(transport)
        addSubview(bufferingSpinner)
        addSubview(scrubberRow)
        addSubview(bottomRow)

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
    /// so we don't fight their finger.
    func setProgress(current: TimeInterval, duration: TimeInterval) {
        currentTimeLabel.text = VideoTime.formatted(current)
        durationLabel.text = VideoTime.formatted(duration)
        if !isScrubbing {
            scrubber.value = VideoTime.progress(current: current, duration: duration)
        }
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

    // MARK: - Actions
    private var isScrubbing = false

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
