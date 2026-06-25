//
//  TrailerPlayerViewController.swift
//  AnimeApp
//
//  A client-owned convenience host that presents a `PlayerSDK` player as a
//  dismissable popup. The player engine is agnostic about who hosts it, so this
//  host controller lives in the app (not the SDK): build a configuration, present
//  this, done. It embeds a `VideoPlayerView` and forwards its delegate.
//

import UIKit
import PlayerSDK

final class TrailerPlayerViewController: UIViewController {

    private let configuration: VideoPlayerConfiguration
    let playerView = VideoPlayerView()

    /// The player exposed through its facade protocol rather than the concrete view.
    var player: VideoPlaying { playerView }

    /// Optional delegate forwarded straight to the embedded `VideoPlayerView`.
    weak var playerDelegate: VideoPlayerDelegate? {
        didSet { playerView.delegate = playerDelegate }
    }

    init(configuration: VideoPlayerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        // A dimmed popup that keeps the presenting screen faintly visible behind.
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player.load(configuration)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
        if #available(iOS 16.0, *) {
            presentingViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
