//
//  AnimeDetailViewController.swift
//  AnimeApp
//
//  VIP View for Anime Detail. Renders the snapshot the Presenter supplies and
//  forwards back/watch intents to the Router. The seed anime (the one tapped)
//  is injected via `configure(with:)` before the screen is pushed.
//

import UIKit
import PlayerSDK

@MainActor
protocol DetailDisplayLogic: AnyObject {
    func displayLoading(_ isLoading: Bool)
    func displayDetail(_ viewModel: Detail.ViewModel)
    func displayError(_ message: String)
}

final class AnimeDetailViewController: UIViewController, DetailDisplayLogic {

    // MARK: - IBOutlets
    @IBOutlet weak var scrollView:          UIScrollView!
    @IBOutlet weak var heroImageView:       UIImageView!
    @IBOutlet weak var titleLabel:          UILabel!
    @IBOutlet weak var scoreLabel:          UILabel!
    @IBOutlet weak var metaLabel:           UILabel!
    @IBOutlet weak var genreLabel:          UILabel!
    @IBOutlet weak var synopsisLabel:       UILabel!
    @IBOutlet weak var watchButton:         UIButton!
    @IBOutlet weak var charsCollectionView: UICollectionView!
    @IBOutlet weak var loadingIndicator:    UIActivityIndicatorView!
    @IBOutlet weak var charsTitleLabel:     UILabel!
    @IBOutlet weak var backButton:          UIButton!
    @IBOutlet weak var synTitleLabel:       UILabel!

    // MARK: - VIP collaborators
    var interactor: DetailBusinessLogic?
    var router: DetailRoutingLogic?

    private var characters: [Detail.Character] = []
    private var currentTitle = ""
    private var trailerYouTubeID: String?
    private var loadedImageURL: URL?
    private var imageTask: Task<Void, Never>?

    private let heroGradient = CAGradientLayer()

    /// The storyboard's fixed hero-height constraint, resolved at setup so we can
    /// drive it adaptively (taller on iPad / landscape) instead of a fixed 380pt.
    private var heroHeightConstraint: NSLayoutConstraint?

    /// Circular "play trailer" button overlaid on the hero poster.
    private let trailerButton = UIButton(type: .system)

    /// Fallback clip for the rare title with no YouTube trailer in the API. Uses
    /// Apple's public HLS test stream — adaptive, fast-starting, and reliably
    /// reachable (a progressive MP4 was hanging at 0:00 on the simulator).
    private static let dummyTrailerURL = URL(
        string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!

    // MARK: - Init / VIP setup
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let interactor = DetailInteractor()
        let presenter = DetailPresenter()
        let router = DetailRouter()

        interactor.presenter = presenter
        presenter.viewController = self
        router.viewController = self

        self.interactor = interactor
        self.router = router
    }

    /// Injected by the routing screen before push.
    func configure(with anime: Anime) {
        interactor?.setInitialAnime(anime)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStructure()
        applyTheme()
        interactor?.load(request: Detail.Load.Request())
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let heroHeight = Layout.detailHeroHeight(forAvailableHeight: view.bounds.height)
        if heroHeightConstraint?.constant != heroHeight {
            heroHeightConstraint?.constant = heroHeight
            view.layoutIfNeeded()
        }
        heroGradient.frame = heroImageView.bounds
    }

    /// Resize character cells when the size class flips (iPad vs iPhone).
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard traitCollection.horizontalSizeClass != previous?.horizontalSizeClass,
              let layout = charsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout
        else { return }
        layout.itemSize = Layout.characterCellSize(for: traitCollection)
        layout.invalidateLayout()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Structure (no colours)
    private func setupStructure() {
        navigationController?.setNavigationBarHidden(true, animated: false)

        heroImageView.contentMode   = .scaleAspectFill
        heroImageView.clipsToBounds = true
        heroImageView.layer.addSublayer(heroGradient)
        heroHeightConstraint = heroImageView.constraints.first {
            $0.firstAttribute == .height && $0.secondItem == nil
        }
        setupTrailerButton()

        titleLabel.font          = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.numberOfLines = 3
        scoreLabel.font          = .systemFont(ofSize: 17, weight: .semibold)
        metaLabel.font           = .systemFont(ofSize: 13)
        genreLabel.font          = .systemFont(ofSize: 12, weight: .semibold)
        synopsisLabel.font       = .systemFont(ofSize: 14)
        synopsisLabel.numberOfLines = 0
        charsTitleLabel.text     = AppStrings.Detail.characters
        charsTitleLabel.font     = .systemFont(ofSize: 17, weight: .semibold)
        synTitleLabel.text       = AppStrings.Detail.synopsis

        watchButton.setTitle(AppStrings.Detail.watchNow, for: .normal)
        watchButton.setTitleColor(.white, for: .normal)
        watchButton.titleLabel?.font    = .systemFont(ofSize: 16, weight: .semibold)
        watchButton.layer.cornerRadius  = 16
        watchButton.layer.shadowOpacity = 0.35
        watchButton.layer.shadowRadius  = 10
        watchButton.layer.shadowOffset  = CGSize(width: 0, height: 4)

        // Back button: configured fully in code so the arrow is always crisp and
        // visible over the hero image, independent of storyboard colours.
        backButton.setTitle(nil, for: .normal)
        backButton.setImage(
            UIImage(systemName: "chevron.left",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)),
            for: .normal)
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.layer.cornerRadius = 22
        backButton.clipsToBounds      = false
        backButton.layer.shadowColor  = UIColor.black.cgColor
        backButton.layer.shadowOpacity = 0.35
        backButton.layer.shadowRadius  = 6
        backButton.layer.shadowOffset  = CGSize(width: 0, height: 2)

        charsCollectionView.showsHorizontalScrollIndicator = false
        charsCollectionView.register(CharacterCell.self, forCellWithReuseIdentifier: CharacterCell.id)
        charsCollectionView.dataSource = self
        charsCollectionView.delegate = self
        if let layout = charsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection         = .horizontal
            layout.itemSize                = Layout.characterCellSize(for: traitCollection)
            layout.minimumInteritemSpacing = 10
            layout.sectionInset            = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        }

        loadingIndicator.hidesWhenStopped = true
    }

    /// Builds the circular play button centered on the hero poster. Tapping it
    /// presents the trailer popup from `PlayerSDK`.
    private func setupTrailerButton() {
        // UIImageView ignores touches by default; enable so the button works.
        heroImageView.isUserInteractionEnabled = true

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "play.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .bold))
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 16)
        trailerButton.configuration = config
        trailerButton.translatesAutoresizingMaskIntoConstraints = false
        trailerButton.addTarget(self, action: #selector(playTrailerTapped), for: .touchUpInside)
        // Long-press the play button to force our custom AVPlayer (PlayerSDK's
        // VideoPlayerView) for ANY title — handy for testing the in-house player,
        // since real titles normally route to YouTube. Plays a sample HLS stream
        // because YouTube trailers can't be opened in AVPlayer.
        trailerButton.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(playCustomTrailerLongPressed)))

        heroImageView.addSubview(trailerButton)
        NSLayoutConstraint.activate([
            trailerButton.centerXAnchor.constraint(equalTo: heroImageView.centerXAnchor),
            trailerButton.centerYAnchor.constraint(equalTo: heroImageView.centerYAnchor),
        ])
    }

    // MARK: - Theme
    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current

        view.backgroundColor               = theme.background
        scrollView.backgroundColor         = theme.background
        charsCollectionView.backgroundColor = .clear

        heroGradient.colors   = [UIColor.clear.cgColor,
                                  theme.background.withAlphaComponent(0.6).cgColor,
                                  theme.background.cgColor]
        heroGradient.locations = [0.45, 0.78, 1.0]

        titleLabel.textColor    = theme.bodyText
        scoreLabel.textColor    = theme.amberScore
        metaLabel.textColor     = theme.secondaryText
        genreLabel.textColor    = theme.accentPrimary
        synopsisLabel.textColor = theme.bodyText.withAlphaComponent(0.85)
        charsTitleLabel.textColor = theme.bodyText

        // Storyboard labels inherit a dynamic default background that turns dark
        // under system Dark Mode; force them transparent so text stays readable.
        [titleLabel, scoreLabel, metaLabel, genreLabel,
         synopsisLabel, charsTitleLabel, synTitleLabel].forEach {
            $0?.backgroundColor = .clear
            $0?.isOpaque = false
        }

        watchButton.backgroundColor     = theme.accentSecondary
        watchButton.layer.shadowColor   = theme.accentSecondary.cgColor

        synTitleLabel?.textColor = theme.bodyText

        // Floating back button sits over an arbitrary hero image, so keep it a
        // consistent dark glass circle with a white chevron in both themes.
        backButton?.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        backButton?.tintColor = .white

        loadingIndicator.color = theme.accentPrimary

        setNeedsStatusBarAppearanceUpdate()
        charsCollectionView.reloadData()
    }

    // MARK: - DetailDisplayLogic

    func displayLoading(_ isLoading: Bool) {
        isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }

    func displayDetail(_ viewModel: Detail.ViewModel) {
        currentTitle       = viewModel.title
        trailerYouTubeID   = viewModel.trailerYouTubeID
        print("[Trailer] displayDetail '\(viewModel.title)' — youtubeID = \(viewModel.trailerYouTubeID ?? "nil")")
        titleLabel.text    = viewModel.title
        scoreLabel.text    = viewModel.score
        metaLabel.text     = viewModel.meta
        genreLabel.text    = viewModel.genres
        synopsisLabel.text = viewModel.synopsis

        loadHeroImage(from: viewModel.heroImageURL)

        let hadCharacters = !characters.isEmpty
        characters = viewModel.characters
        charsCollectionView.reloadData()
        if !characters.isEmpty && !hadCharacters {
            charsCollectionView.alpha = 0
            UIView.animate(withDuration: 0.3) { self.charsCollectionView.alpha = 1 }
        }
    }

    func displayError(_ message: String) {
        let alert = UIAlertController(title: AppStrings.Common.oops, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    private func loadHeroImage(from url: URL?) {
        guard let url, url != loadedImageURL else { return }
        loadedImageURL = url
        imageTask?.cancel()
        imageTask = Task {
            if let img = await ImageLoader.shared.image(from: url) {
                await MainActor.run {
                    UIView.transition(with: self.heroImageView, duration: 0.3,
                                      options: .transitionCrossDissolve) {
                        self.heroImageView.image = img
                    }
                }
            }
        }
    }

    // MARK: - IBActions
    @IBAction func backTapped(_ sender: UIButton) {
        router?.dismiss()
    }

    @IBAction func watchTapped(_ sender: UIButton) {
        router?.presentWatch(title: currentTitle)
    }

    /// Presents the trailer for the current anime. Prefers the real YouTube
    /// trailer (like MyAnimeList); falls back to a dummy clip if the title has
    /// no trailer in the API.
    @objc private func playTrailerTapped() {
        print("[Trailer] tapped — trailerYouTubeID = \(trailerYouTubeID ?? "nil")")
        if let youTubeID = trailerYouTubeID {
            let trailerVC = YouTubeTrailerViewController(videoID: youTubeID, title: currentTitle)
            trailerVC.delegate = self
            present(trailerVC, animated: true)
        } else {
            presentCustomPlayer()
        }
    }

    /// Long-press handler: always opens our in-house AVPlayer, regardless of
    /// whether the title has a YouTube trailer. Lets us exercise the custom
    /// player on any anime.
    @objc private func playCustomTrailerLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }   // fire once per press
        print("[Trailer] long-press — forcing custom AVPlayer")
        presentCustomPlayer()
    }

    /// Presents PlayerSDK's `VideoPlayerView` (our custom AVPlayer) with a sample
    /// stream. Used for titles without a YouTube trailer and for the long-press
    /// test path above.
    private func presentCustomPlayer() {
        let config = VideoPlayerConfiguration(
            url: Self.dummyTrailerURL,
            title: currentTitle.isEmpty ? AppStrings.Detail.watchNow : currentTitle,
            autoPlay: true)
        let playerVC = TrailerPlayerViewController(configuration: config)
        playerVC.playerDelegate = self   // observe all player callbacks
        present(playerVC, animated: true)
    }
}

// MARK: - VideoPlayerDelegate (dummy AVPlayer fallback)
// Demonstrates the SDK callback surface. Hook analytics or UI here as needed.
extension AnimeDetailViewController: VideoPlayerDelegate {

    func videoPlayer(_ player: VideoPlayerView, didChangeState state: VideoPlayerState) {
        print("[Trailer] state -> \(state)")
    }

    func videoPlayer(_ player: VideoPlayerView, didBecomeReadyWithDuration duration: TimeInterval) {
        print("[Trailer] ready, duration = \(VideoTime.formatted(duration))")
    }

    func videoPlayerDidFinish(_ player: VideoPlayerView) {
        print("[Trailer] finished playing")
    }

    func videoPlayer(_ player: VideoPlayerView, didFailWithError error: Error) {
        print("[Trailer] failed: \(error.localizedDescription)")
    }
}

// MARK: - YouTubeTrailerDelegate (real YouTube trailer)
extension AnimeDetailViewController: YouTubeTrailerDelegate {

    func youTubeTrailerDidBecomeReady(_ controller: YouTubeTrailerViewController) {
        print("[Trailer] YouTube ready")
    }

    func youTubeTrailer(_ controller: YouTubeTrailerViewController, didChangeState state: VideoPlayerState) {
        print("[Trailer] YouTube state -> \(state)")
    }

    func youTubeTrailer(_ controller: YouTubeTrailerViewController, didFailWithError error: Error) {
        print("[Trailer] YouTube failed: \(error.localizedDescription)")
    }
}

extension AnimeDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { characters.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(
            withReuseIdentifier: CharacterCell.id, for: ip) as! CharacterCell
        cell.configure(with: characters[ip.item])
        return cell
    }

    /// Tapping a character opens its full profile (bio, voice actors, …).
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        let character = characters[ip.item]
        router?.routeToCharacter(id: character.id, name: character.name, imageURL: character.imageURL)
    }
}
