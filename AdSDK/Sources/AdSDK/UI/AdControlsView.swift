//
//  AdControlsView.swift
//  AdSDK
//
//  The chrome drawn over a playing ad: an "Ad x of y" badge, a remaining-time
//  countdown, a "Learn More" clickthrough button, a Skip button that unlocks after
//  the VAST skipoffset, and a thin progress bar. Pure presentation — it exposes
//  `onSkip` / `onLearnMore` closures and setter methods; all logic lives in
//  ``AdOverlayView``.
//

import UIKit

final class AdControlsView: UIView {

    var onSkip: (() -> Void)?
    var onLearnMore: (() -> Void)?

    private let accentColor: UIColor

    private let badgeLabel = UILabel()
    private let countdownLabel = UILabel()
    private let learnMoreButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressFillWidth: NSLayoutConstraint!

    init(accentColor: UIColor) {
        self.accentColor = accentColor
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.accentColor = .systemYellow
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.layer.masksToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        countdownLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        countdownLabel.textColor = .white
        countdownLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        countdownLabel.textAlignment = .center
        countdownLabel.layer.cornerRadius = 4
        countdownLabel.layer.masksToBounds = true
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        var learnCfg = UIButton.Configuration.filled()
        learnCfg.title = "Learn More"
        learnCfg.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
        learnCfg.baseForegroundColor = .white
        learnCfg.cornerStyle = .small
        learnCfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        learnMoreButton.configuration = learnCfg
        learnMoreButton.translatesAutoresizingMaskIntoConstraints = false
        learnMoreButton.addTarget(self, action: #selector(learnMoreTapped), for: .touchUpInside)

        var skipCfg = UIButton.Configuration.filled()
        skipCfg.baseBackgroundColor = UIColor.black.withAlphaComponent(0.6)
        skipCfg.baseForegroundColor = .white
        skipCfg.cornerStyle = .small
        skipCfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        skipButton.configuration = skipCfg
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = accentColor
        progressFill.translatesAutoresizingMaskIntoConstraints = false

        addSubview(badgeLabel)
        addSubview(countdownLabel)
        addSubview(learnMoreButton)
        addSubview(skipButton)
        addSubview(progressTrack)
        progressTrack.addSubview(progressFill)

        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            badgeLabel.heightAnchor.constraint(equalToConstant: 20),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),

            countdownLabel.bottomAnchor.constraint(equalTo: progressTrack.topAnchor, constant: -10),
            countdownLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            countdownLabel.heightAnchor.constraint(equalToConstant: 22),
            countdownLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),

            learnMoreButton.centerYAnchor.constraint(equalTo: countdownLabel.centerYAnchor),
            learnMoreButton.leadingAnchor.constraint(equalTo: countdownLabel.trailingAnchor, constant: 8),

            skipButton.centerYAnchor.constraint(equalTo: countdownLabel.centerYAnchor),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            progressTrack.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressTrack.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 3),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFillWidth,
        ])
    }

    // MARK: - Configuration

    /// Sets the "Ad x of y" badge and whether the skip button is relevant at all.
    func configure(adIndex: Int, count: Int, isSkippable: Bool) {
        badgeLabel.text = "  Ad \(adIndex + 1) of \(count)  "
        skipButton.isHidden = !isSkippable
    }

    func setCountdown(remaining: TimeInterval) {
        let total = max(0, Int(remaining.rounded()))
        countdownLabel.text = "  Ad \u{00B7} \(format(total))  "
    }

    /// Updates the skip button: locked countdown vs the active skip affordance.
    func setSkip(enabled: Bool, secondsUntilSkippable: Int) {
        skipButton.isEnabled = enabled
        var cfg = skipButton.configuration
        if enabled {
            cfg?.title = "Skip Ad \u{23ED}"
            cfg?.baseForegroundColor = .white
        } else {
            cfg?.title = "Skip in \(max(0, secondsUntilSkippable))"
            cfg?.baseForegroundColor = UIColor.white.withAlphaComponent(0.7)
        }
        skipButton.configuration = cfg
    }

    func setLearnMoreVisible(_ visible: Bool) {
        learnMoreButton.isHidden = !visible
    }

    func setProgress(current: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else { progressFillWidth.constant = 0; return }
        let fraction = CGFloat(min(max(current / duration, 0), 1))
        progressFillWidth.constant = bounds.width * fraction
    }

    // MARK: - Actions

    @objc private func skipTapped() { onSkip?() }
    @objc private func learnMoreTapped() { onLearnMore?() }

    private func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
