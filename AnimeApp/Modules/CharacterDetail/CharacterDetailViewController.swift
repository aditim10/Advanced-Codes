//
//  CharacterDetailViewController.swift
//  AnimeApp
//
//  VIP View for Character Detail. Renders a character's portrait, names,
//  favourites, biography, and voice actors. Built programmatically (no
//  storyboard) and pushed from the Anime Detail screen via `init(characterID:…)`.
//

import UIKit
import ImageLoaderKit

@MainActor
protocol CharacterDetailDisplayLogic: AnyObject {
    func displayLoading(_ isLoading: Bool)
    func displayCharacter(_ viewModel: CharacterDetail.ViewModel)
    func displayError(_ message: String)
}

final class CharacterDetailViewController: UIViewController, CharacterDetailDisplayLogic {

    // MARK: - VIP collaborators
    var interactor: CharacterDetailBusinessLogic?
    var router: CharacterDetailRoutingLogic?

    // MARK: - Seed (shown instantly while the full profile loads)
    private let seedName: String
    private let seedImageURL: URL?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private let portraitContainer = UIView()
    private let portraitImageView = UIImageView()
    private let nameLabel = UILabel()
    private let kanjiLabel = UILabel()
    private let favoritesLabel = UILabel()
    private let nicknamesLabel = UILabel()
    private let aboutTitleLabel = UILabel()
    private let aboutLabel = UILabel()
    private let aboutToggleButton = UIButton(type: .system)
    private let voiceActorsTitleLabel = UILabel()
    private let voiceActorsStack = UIStackView()

    /// "Read more / Read less" state for the (often very long) biography.
    private var isAboutExpanded = false
    private let collapsedAboutLines = 6

    private var portraitImageTask: Task<Void, Never>?

    // MARK: - Init / VIP setup
    init(characterID: Int, name: String, imageURL: URL?) {
        self.seedName = name
        self.seedImageURL = imageURL
        super.init(nibName: nil, bundle: nil)
        setup(characterID: characterID)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setup(characterID: Int) {
        let interactor = CharacterDetailInteractor(characterID: characterID)
        let presenter = CharacterDetailPresenter()
        let router = CharacterDetailRouter()

        interactor.presenter = presenter
        presenter.viewController = self
        router.viewController = self

        self.interactor = interactor
        self.router = router
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = seedName
        buildUI()
        applyTheme()
        seedFromInjectedData()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
        interactor?.load(request: CharacterDetail.Load.Request())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The Anime Detail screen hides the nav bar; this leaf screen shows it so
        // the user gets a themed back button.
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAboutReadMoreVisibility()
    }

    // MARK: - Build UI
    private func buildUI() {
        configureScrollView()
        configurePortrait()
        configureLabels()
        configureVoiceActors()
        assembleContentStack()
        configureLoadingIndicator()
        activateConstraints()
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
    }

    private func configurePortrait() {
        // Portrait, centered in a full-width container.
        portraitImageView.contentMode = .scaleAspectFill
        portraitImageView.clipsToBounds = true
        portraitImageView.layer.cornerRadius = 16
        portraitImageView.translatesAutoresizingMaskIntoConstraints = false
        portraitContainer.translatesAutoresizingMaskIntoConstraints = false
        portraitContainer.addSubview(portraitImageView)
    }

    private func configureLabels() {
        nameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        nameLabel.numberOfLines = 0
        nameLabel.textAlignment = .center

        kanjiLabel.font = .systemFont(ofSize: 15)
        kanjiLabel.textAlignment = .center
        kanjiLabel.numberOfLines = 0

        favoritesLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        favoritesLabel.textAlignment = .center

        nicknamesLabel.font = .systemFont(ofSize: 13)
        nicknamesLabel.textAlignment = .center
        nicknamesLabel.numberOfLines = 0

        aboutTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        aboutTitleLabel.text = AppStrings.Character.about

        aboutLabel.font = .systemFont(ofSize: 14)
        aboutLabel.numberOfLines = collapsedAboutLines

        aboutToggleButton.setTitle(AppStrings.Detail.readMore, for: .normal)
        aboutToggleButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        aboutToggleButton.contentHorizontalAlignment = .leading
        aboutToggleButton.addTarget(self, action: #selector(toggleAbout), for: .touchUpInside)
        aboutToggleButton.isHidden = true

        voiceActorsTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        voiceActorsTitleLabel.text = AppStrings.Character.voiceActors
    }

    private func configureVoiceActors() {
        voiceActorsStack.axis = .vertical
        voiceActorsStack.spacing = 12
    }

    private func assembleContentStack() {
        // Assemble. Custom spacing adds a little breathing room before section headers.
        contentStack.addArrangedSubview(portraitContainer)
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(kanjiLabel)
        contentStack.addArrangedSubview(favoritesLabel)
        contentStack.addArrangedSubview(nicknamesLabel)
        contentStack.setCustomSpacing(22, after: nicknamesLabel)
        contentStack.addArrangedSubview(aboutTitleLabel)
        contentStack.addArrangedSubview(aboutLabel)
        contentStack.setCustomSpacing(4, after: aboutLabel)
        contentStack.addArrangedSubview(aboutToggleButton)
        contentStack.setCustomSpacing(22, after: aboutToggleButton)
        contentStack.addArrangedSubview(voiceActorsTitleLabel)
        contentStack.addArrangedSubview(voiceActorsStack)
    }

    private func configureLoadingIndicator() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
    }

    private func activateConstraints() {
        let frame = scrollView.frameLayoutGuide
        let content = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -40),

            portraitImageView.topAnchor.constraint(equalTo: portraitContainer.topAnchor),
            portraitImageView.bottomAnchor.constraint(equalTo: portraitContainer.bottomAnchor),
            portraitImageView.centerXAnchor.constraint(equalTo: portraitContainer.centerXAnchor),
            portraitImageView.widthAnchor.constraint(equalToConstant: 180),
            portraitImageView.heightAnchor.constraint(equalToConstant: 260),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func seedFromInjectedData() {
        nameLabel.text = seedName
        loadPortrait(from: seedImageURL)
    }

    // MARK: - Read more / Read less (biography)

    @objc private func toggleAbout() {
        isAboutExpanded.toggle()
        aboutLabel.numberOfLines = isAboutExpanded ? 0 : collapsedAboutLines
        aboutToggleButton.setTitle(
            isAboutExpanded ? AppStrings.Detail.readLess : AppStrings.Detail.readMore,
            for: .normal)
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    /// Shows the toggle only when the biography genuinely overflows the collapsed
    /// line count. Runs after layout so the label has a resolved width.
    private func updateAboutReadMoreVisibility() {
        guard let text = aboutLabel.text, !text.isEmpty,
              aboutLabel.bounds.width > 0,
              let font = aboutLabel.font else { return }
        let maxSize = CGSize(width: aboutLabel.bounds.width, height: .greatestFiniteMagnitude)
        let bounding = (text as NSString).boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        let totalLines = Int(ceil(bounding.height / font.lineHeight))
        let needsTruncation = totalLines > collapsedAboutLines
        aboutToggleButton.isHidden = !needsTruncation
        if !needsTruncation {
            aboutLabel.numberOfLines = 0
        } else if !isAboutExpanded {
            aboutLabel.numberOfLines = collapsedAboutLines
        }
    }

    // MARK: - Theme
    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        view.backgroundColor = theme.background
        portraitImageView.backgroundColor = theme.shimmerColor
        nameLabel.textColor = theme.bodyText
        kanjiLabel.textColor = theme.secondaryText
        favoritesLabel.textColor = theme.amberScore
        nicknamesLabel.textColor = theme.secondaryText
        aboutTitleLabel.textColor = theme.bodyText
        aboutLabel.textColor = theme.bodyText.withAlphaComponent(0.85)
        aboutToggleButton.setTitleColor(theme.accentPrimary, for: .normal)
        voiceActorsTitleLabel.textColor = theme.bodyText
        loadingIndicator.color = theme.accentPrimary
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - CharacterDetailDisplayLogic
    func displayLoading(_ isLoading: Bool) {
        isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }

    func displayCharacter(_ viewModel: CharacterDetail.ViewModel) {
        nameLabel.text = viewModel.name

        kanjiLabel.text = viewModel.kanji
        kanjiLabel.isHidden = viewModel.kanji == nil

        favoritesLabel.text = viewModel.favorites.map { "♥ \($0)" }
        favoritesLabel.isHidden = viewModel.favorites == nil

        nicknamesLabel.text = viewModel.nicknames.map { "\(AppStrings.Character.alsoKnownAs): \($0)" }
        nicknamesLabel.isHidden = viewModel.nicknames == nil

        aboutLabel.text = viewModel.about ?? AppStrings.Character.noAbout
        // Reset the read-more state for the freshly-loaded bio; visibility is
        // recomputed on the next layout pass once the label has a width.
        isAboutExpanded = false
        aboutLabel.numberOfLines = collapsedAboutLines
        aboutToggleButton.setTitle(AppStrings.Detail.readMore, for: .normal)
        view.setNeedsLayout()

        if let url = viewModel.imageURL { loadPortrait(from: url) }

        rebuildVoiceActors(viewModel.voiceActors)
    }

    func displayError(_ message: String) {
        let alert = UIAlertController(title: AppStrings.Common.oops, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.Common.ok, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Helpers
    private func rebuildVoiceActors(_ actors: [CharacterDetail.VoiceActor]) {
        voiceActorsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        voiceActorsTitleLabel.isHidden = actors.isEmpty
        voiceActorsStack.isHidden = actors.isEmpty
        for actor in actors {
            let row = VoiceActorRowView()
            row.configure(with: actor)
            voiceActorsStack.addArrangedSubview(row)
        }
    }

    private func loadPortrait(from url: URL?) {
        portraitImageTask?.cancel()
        guard let url else { return }
        portraitImageTask = Task {
            if let image = await ImageLoader.shared.image(from: url) {
                await MainActor.run {
                    UIView.transition(with: self.portraitImageView, duration: 0.2,
                                      options: .transitionCrossDissolve) {
                        self.portraitImageView.image = image
                    }
                }
            }
        }
    }
}

// MARK: - VoiceActorRowView

/// A single "avatar + name + language" row in the voice-actors list. Observes
/// theme changes itself, mirroring the reusable cells.
private final class VoiceActorRowView: UIView {

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let languageLabel = UILabel()
    private var imageTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func setup() {
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 24
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.numberOfLines = 1
        languageLabel.font = .systemFont(ofSize: 12)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, languageLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(avatarView)
        addSubview(textStack)
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),
            avatarView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            avatarView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        avatarView.backgroundColor = theme.shimmerColor
        nameLabel.textColor = theme.bodyText
        languageLabel.textColor = theme.secondaryText
    }

    func configure(with actor: CharacterDetail.VoiceActor) {
        nameLabel.text = actor.name
        languageLabel.text = actor.language
        avatarView.image = nil
        imageTask?.cancel()
        guard let url = actor.imageURL else { return }
        imageTask = Task {
            if let image = await ImageLoader.shared.image(from: url) {
                await MainActor.run { self.avatarView.image = image }
            }
        }
    }
}
