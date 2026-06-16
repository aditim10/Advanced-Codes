//
//  AnimeDetailViewController.swift
//  AnimeApp
//
//  VIP View for Anime Detail. Renders the snapshot the Presenter supplies and
//  forwards back/watch intents to the Router. The seed anime (the one tapped)
//  is injected via `configure(with:)` before the screen is pushed.
//

import UIKit

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
    private var loadedImageURL: URL?
    private var imageTask: Task<Void, Never>?

    private let heroGradient = CAGradientLayer()

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
        heroGradient.frame = heroImageView.bounds
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
        if let layout = charsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection         = .horizontal
            layout.itemSize                = CGSize(width: 80, height: 110)
            layout.minimumInteritemSpacing = 10
            layout.sectionInset            = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        }

        loadingIndicator.hidesWhenStopped = true
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
}

extension AnimeDetailViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { characters.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(
            withReuseIdentifier: CharacterCell.id, for: ip) as! CharacterCell
        cell.configure(with: characters[ip.item])
        return cell
    }
}
