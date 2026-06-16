//
//  TrailerPlayerViewController.swift
//  PlayerSDK
//
//  A drop-in popup that plays a single configuration and dismisses itself. This
//  is the easiest entry point for clients: build a configuration, present this,
//  done. It embeds a `VideoPlayerView` and forwards its delegate.
//

import UIKit

public final class TrailerPlayerViewController: UIViewController {

    private let configuration: VideoPlayerConfiguration
    public let playerView = VideoPlayerView()

    /// Optional delegate forwarded straight to the embedded `VideoPlayerView`.
    public weak var playerDelegate: VideoPlayerDelegate? {
        didSet { playerView.delegate = playerDelegate }
    }

    public init(configuration: VideoPlayerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        // A dimmed popup that keeps the presenting screen faintly visible behind.
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.92)

        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.backgroundColor = .black
        playerView.layer.cornerRadius = 16
        playerView.clipsToBounds = true
        view.addSubview(playerView)

        let safe = view.safeAreaLayoutGuide
        // Aspect-fit a 16:9 player inside the safe area: centered, as large as
        // possible, but never wider/taller than the screen. This keeps it correct
        // in BOTH portrait (width-bound) and landscape (height-bound) 
        let maxWidth = playerView.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -24)
        let maxHeight = playerView.heightAnchor.constraint(lessThanOrEqualTo: safe.heightAnchor, constant: -24)
        let preferWidth = playerView.widthAnchor.constraint(equalTo: safe.widthAnchor, constant: -24)
        preferWidth.priority = .defaultHigh
        let preferHeight = playerView.heightAnchor.constraint(equalTo: safe.heightAnchor, constant: -24)
        preferHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            playerView.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            playerView.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9.0 / 16.0),
            maxWidth, maxHeight, preferWidth, preferHeight,
        ])

        // The player's close button dismisses the popup.
        playerView.onRequestClose = { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playerView.load(configuration)
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playerView.pause()
        if #available(iOS 16.0, *) {
            presentingViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
