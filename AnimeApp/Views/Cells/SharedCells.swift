import UIKit
import ImageLoaderKit

// MARK: - RatingBadge

/// Builds a "★ 8.6" score line where the star is a solid, tinted `star.fill`
/// SF Symbol rather than the multicolour ⭐ emoji (which renders faintly and
/// inconsistently over posters / gradients). The star is tinted to match the
/// score colour so the rating reads as one cohesive badge.
enum RatingBadge {
    static func attributed(_ score: String, color: UIColor, fontSize: CGFloat) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let result = NSMutableAttributedString()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .semibold)
        if let star = UIImage(systemName: "star.fill", withConfiguration: symbolConfig)?
            .withTintColor(color, renderingMode: .alwaysOriginal) {
            let attachment = NSTextAttachment(image: star)
            let size = star.size
            attachment.bounds = CGRect(x: 0,
                                       y: (font.capHeight - size.height) / 2,
                                       width: size.width,
                                       height: size.height)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " "))
        }
        result.append(NSAttributedString(string: score,
                                         attributes: [.foregroundColor: color, .font: font]))
        return result
    }
}

// MARK: - AnimeCardDisplaying

/// Render-ready fields a poster cell/banner needs. Both the domain `Anime` model
/// and the dumb VIP snapshots (`Home.Card`, `Home.Banner`) conform, so the shared
/// cells stay decoupled from any one module and from the domain layer.
protocol AnimeCardDisplaying {
    var cardID: Int { get }
    var cardTitle: String { get }
    var cardMeta: String { get }
    var cardScore: String { get }
    var cardPosterURL: URL? { get }
}

extension Anime: AnimeCardDisplaying {
    var cardID: Int { malID }
    var cardTitle: String { displayTitle }
    var cardMeta: String { [yearText, episodesText].joined(separator: "  ·  ") }
    var cardScore: String { scoreText }
    var cardPosterURL: URL? { posterURL }
}

// MARK: - CharacterDisplaying

/// Render-ready fields the `CharacterCell` needs. `CharacterEntry` (domain) and
/// the dumb `Detail.Character` snapshot both conform.
protocol CharacterDisplaying {
    var characterName: String { get }
    var characterImageURL: URL? { get }
}

extension CharacterEntry: CharacterDisplaying {
    var characterName: String { character.name }
    var characterImageURL: URL? { character.imageURL }
}

// MARK: - BannerView
final class BannerView: UIView {

    /// Fired with the tapped item's id (e.g. MyAnimeList id).
    var onSelect: ((Int) -> Void)?
    private var items: [AnimeCardDisplaying] = []
    private var currentIndex = 0
    private var autoScrollTimer: Timer?

    /// `true` until the first batch of banners has been supplied.
    var isEmpty: Bool { items.isEmpty }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.isPagingEnabled = true
        cv.register(BannerCell.self, forCellWithReuseIdentifier: BannerCell.id)
        cv.dataSource = self; cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let pageControl: UIPageControl = {
        let p = UIPageControl()
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private let placeholderView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 20
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        layer.cornerRadius = 0
        addSubview(placeholderView)
        addSubview(collectionView)
        addSubview(pageControl)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            placeholderView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            placeholderView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            placeholderView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            placeholderView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -60),
        ])
        startPlaceholderShimmer()
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    deinit {
        autoScrollTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        backgroundColor = theme.background
        placeholderView.backgroundColor = theme.shimmerColor
        pageControl.currentPageIndicatorTintColor = theme.accentPrimary
        pageControl.pageIndicatorTintColor = theme.accentPrimary.withAlphaComponent(0.25)
        collectionView.reloadData()
    }

    private func startPlaceholderShimmer() {
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 0.45; a.toValue = 0.9; a.duration = 0.9
        a.autoreverses = true; a.repeatCount = .infinity
        placeholderView.layer.add(a, forKey: "shimmer")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = bounds.size
    }

    func configure(with items: [AnimeCardDisplaying]) {
        self.items = items
        pageControl.numberOfPages = items.count
        pageControl.isHidden = items.count <= 1
        let hasContent = !items.isEmpty
        placeholderView.isHidden = hasContent
        if hasContent {
            placeholderView.layer.removeAnimation(forKey: "shimmer")
        }
        collectionView.reloadData()
        startAutoScroll()
    }

    private func startAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            self?.scrollToNext()
        }
    }

    private func scrollToNext() {
        guard !items.isEmpty else { return }
        currentIndex = (currentIndex + 1) % items.count
        collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0),
                                    at: .centeredHorizontally, animated: true)
        pageControl.currentPage = currentIndex
    }
}

extension BannerView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { items.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: BannerCell.id, for: ip) as! BannerCell
        cell.configure(with: items[ip.item]); return cell
    }
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        onSelect?(items[ip.item].cardID)
    }
    func scrollViewDidEndDecelerating(_ sv: UIScrollView) {
        currentIndex = Int(sv.contentOffset.x / sv.frame.width)
        pageControl.currentPage = currentIndex
    }
}

// MARK: - BannerCell
final class BannerCell: UICollectionViewCell {
    static let id = "BannerCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
        iv.layer.cornerRadius = 20
        iv.translatesAutoresizingMaskIntoConstraints = false; return iv
    }()

    private let infoBlur: UIVisualEffectView = {
        // Always-dark glass so caption text stays legible over any poster,
        // regardless of light/dark app theme.
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.layer.cornerRadius = 14
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private let scoreLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()

    private var imageTask: Task<Void, Never>?

    /// Gold used for both the star glyph and the score digits so the rating reads
    /// as one solid badge over any poster.
    private static let scoreColor = UIColor(red: 1.00, green: 0.82, blue: 0.30, alpha: 1)

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.addSubview(imageView)
        // Strong dark scrim on top of the blur. A translucent material alone goes
        // light over bright posters (washing out white text), so we keep the panel
        // reliably dark for high caption contrast over ANY poster, in both themes.
        infoBlur.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        infoBlur.contentView.addSubview(titleLabel)
        infoBlur.contentView.addSubview(metaLabel)
        infoBlur.contentView.addSubview(scoreLabel)
        contentView.addSubview(infoBlur)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -60),

            infoBlur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            infoBlur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            // Pin the caption fully *inside* the poster (12pt above its bottom). The
            // panel is intentionally always-dark, so any part hanging below the poster
            // would float as a black box on the page background — fine in dark theme
            // but jarring in light theme. Keeping it on the poster looks good in both.
            infoBlur.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -12),
            infoBlur.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: infoBlur.contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: infoBlur.contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: infoBlur.contentView.trailingAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            metaLabel.leadingAnchor.constraint(equalTo: infoBlur.contentView.leadingAnchor, constant: 12),

            scoreLabel.centerYAnchor.constraint(equalTo: metaLabel.centerYAnchor),
            scoreLabel.leadingAnchor.constraint(equalTo: metaLabel.trailingAnchor, constant: 8),
        ])
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        backgroundColor = theme.background
        // Caption sits on a dark glass panel — keep text light in both themes,
        // with a subtle shadow for guaranteed legibility over any poster.
        titleLabel.textColor = .white
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        scoreLabel.textColor = Self.scoreColor
        [titleLabel, metaLabel, scoreLabel].forEach {
            $0.shadowColor = UIColor.black.withAlphaComponent(0.55)
            $0.shadowOffset = CGSize(width: 0, height: 1)
        }
    }

    func configure(with item: AnimeCardDisplaying) {
        titleLabel.text = item.cardTitle
        metaLabel.text = item.cardMeta
        scoreLabel.attributedText = RatingBadge.attributed(item.cardScore, color: Self.scoreColor, fontSize: 12)
        imageView.image = nil; imageTask?.cancel()
        if let url = item.cardPosterURL {
            imageTask = Task {
                if let img = await ImageLoader.shared.image(from: url) {
                    await MainActor.run { self.imageView.image = img }
                }
            }
        }
    }
    override func prepareForReuse() {
        super.prepareForReuse(); imageTask?.cancel(); imageView.image = nil
    }
}

// MARK: - SectionRowCell
final class SectionRowCell: UITableViewCell {
    static let id = "SectionRowCell"

    /// Fired with the tapped card's id (MyAnimeList id).
    var onCardSelected: ((Int) -> Void)?
    /// Fired when the row's title or "See all" button is tapped.
    var onSeeAll: (() -> Void)?
    private var cards: [AnimeCardDisplaying] = []

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.isUserInteractionEnabled = true   // tapping the title also opens "See all"
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()

    private let seeAllButton: UIButton = {
        var cfg = UIButton.Configuration.plain()
        cfg.title = AppStrings.Common.seeAll
        cfg.image = UIImage(systemName: "chevron.right",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        cfg.imagePlacement = .trailing
        cfg.imagePadding = 3
        // Generous insets so it's an easy, reliable tap target.
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 8)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var b = a; b.font = .systemFont(ofSize: 13, weight: .semibold); return b
        }
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false; return b
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        // Item size comes from the flow-layout delegate (adaptive per size class);
        // estimatedItemSize stays default so `sizeForItemAt` is authoritative.
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(AnimeCardCell.self, forCellWithReuseIdentifier: AnimeCardCell.id)
        cv.dataSource = self; cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false; return cv
    }()

    private let shimmerView: ShimmerRowView = {
        let s = ShimmerRowView()
        s.translatesAutoresizingMaskIntoConstraints = false; return s
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(titleLabel)
        contentView.addSubview(seeAllButton)
        contentView.addSubview(collectionView)
        contentView.addSubview(shimmerView)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),

            seeAllButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            shimmerView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
        ])
        seeAllButton.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        titleLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(seeAllTapped)))
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    // Poster cards grow on regular-width (iPad) contexts; re-layout when the size
    // class flips so the carousel reflows.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.horizontalSizeClass != previous?.horizontalSizeClass {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        titleLabel.textColor = theme.bodyText
        var cfg = seeAllButton.configuration ?? .plain()
        cfg.baseForegroundColor = theme.accentPrimary
        seeAllButton.configuration = cfg
    }

    /// Renders a dumb snapshot row: a title, its poster cards, and a loading flag.
    func configure(title: String, cards: [AnimeCardDisplaying], isLoading: Bool) {
        titleLabel.text = title
        self.cards = cards
        let showShimmer = isLoading && cards.isEmpty
        shimmerView.isHidden = !showShimmer
        showShimmer ? shimmerView.startAnimating() : shimmerView.stopAnimating()
        collectionView.reloadData()
    }

    @objc private func seeAllTapped() {
        onSeeAll?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cards = []
        collectionView.reloadData()
    }
}

extension SectionRowCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { cards.count }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: AnimeCardCell.id, for: ip) as! AnimeCardCell
        cell.configure(with: cards[ip.item]); return cell
    }
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        onCardSelected?(cards[ip.item].cardID)
    }
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt ip: IndexPath) -> CGSize {
        Layout.posterCardSize(for: traitCollection)
    }
}

// MARK: - AnimeCardCell
final class AnimeCardCell: UICollectionViewCell {
    static let id = "AnimeCardCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
        iv.layer.cornerRadius = 14
        iv.translatesAutoresizingMaskIntoConstraints = false; return iv
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private let scoreLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()

    private let card: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.layer.shadowOpacity = 1
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false; return v
    }()

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.94, y: 0.94)
                    : .identity
            }
        }
    }

    private var imageTask: Task<Void, Never>?

    /// Raw score string, kept so the tinted star badge can be rebuilt when the
    /// theme (and therefore the amber colour) changes.
    private var scoreValue: String?

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func setup() {
        backgroundColor = .clear
        contentView.addSubview(card)
        card.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(scoreLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // Poster scales with the cell width instead of a fixed height, so the
            // same cell looks right at any card size (iPhone vs iPad).
            card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: Layout.posterImageRatio),

            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            scoreLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 6),
            scoreLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),

            titleLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 2),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
        ])
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        imageView.backgroundColor = theme.shimmerColor
        card.backgroundColor = theme.cardBackground
        card.layer.shadowColor = theme.accentPrimary.withAlphaComponent(0.14).cgColor
        titleLabel.textColor = theme.bodyText
        scoreLabel.textColor = theme.amberScore
        refreshScore()
    }

    private func refreshScore() {
        guard let scoreValue else { return }
        scoreLabel.attributedText = RatingBadge.attributed(
            scoreValue, color: ThemeManager.shared.current.amberScore, fontSize: 10)
    }

    func configure(with item: AnimeCardDisplaying) {
        titleLabel.text = item.cardTitle
        scoreValue = item.cardScore
        refreshScore()
        imageView.image = nil; imageTask?.cancel()
        if let url = item.cardPosterURL {
            imageTask = Task {
                if let img = await ImageLoader.shared.image(from: url) {
                    await MainActor.run {
                        UIView.transition(with: self.imageView, duration: 0.2,
                                          options: .transitionCrossDissolve) {
                            self.imageView.image = img
                        }
                    }
                }
            }
        }
    }
    override func prepareForReuse() { super.prepareForReuse(); imageTask?.cancel(); imageView.image = nil }
}

// MARK: - CharacterCell
final class CharacterCell: UICollectionViewCell {
    static let id = "CharacterCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
        iv.layer.cornerRadius = 32
        iv.layer.borderWidth = 2
        iv.translatesAutoresizingMaskIntoConstraints = false; return iv
    }()
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textAlignment = .center; l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private var imageTask: Task<Void, Never>?

    /// Avatar size constraints, updated so the circle scales with the size class.
    private var avatarDimensionConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        [imageView, nameLabel].forEach { contentView.addSubview($0) }
        let diameter = Layout.characterAvatarDiameter(for: traitCollection)
        let widthC = imageView.widthAnchor.constraint(equalToConstant: diameter)
        let heightC = imageView.heightAnchor.constraint(equalToConstant: diameter)
        avatarDimensionConstraints = [widthC, heightC]
        imageView.layer.cornerRadius = diameter / 2
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            widthC,
            heightC,
            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 5),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard traitCollection.horizontalSizeClass != previous?.horizontalSizeClass else { return }
        let diameter = Layout.characterAvatarDiameter(for: traitCollection)
        avatarDimensionConstraints.forEach { $0.constant = diameter }
        imageView.layer.cornerRadius = diameter / 2
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        imageView.backgroundColor = theme.shimmerColor
        imageView.layer.borderColor = theme.accentPrimary.withAlphaComponent(0.3).cgColor
        nameLabel.textColor = theme.secondaryText
    }

    func configure(with item: CharacterDisplaying) {
        nameLabel.text = item.characterName
        imageView.image = nil; imageTask?.cancel()
        if let url = item.characterImageURL {
            imageTask = Task {
                if let img = await ImageLoader.shared.image(from: url) {
                    await MainActor.run { self.imageView.image = img }
                }
            }
        }
    }
    override func prepareForReuse() { super.prepareForReuse(); imageTask?.cancel(); imageView.image = nil }
}

// MARK: - ShimmerRowView
final class ShimmerRowView: UIView {
    private let stack: UIStackView = {
        let s = UIStackView(); s.axis = .horizontal; s.spacing = 12
        s.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        s.isLayoutMarginsRelativeArrangement = true
        s.translatesAutoresizingMaskIntoConstraints = false; return s
    }()

    /// Width constraints of the placeholder bars, kept so they can track the
    /// adaptive poster-card width when the size class changes.
    private var barWidthConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = true               // bars overflow the right edge by design
        addSubview(stack)
        // NOTE: the stack is intentionally NOT pinned to the trailing edge. The five
        // fixed-width (115pt) bars total ~575pt — wider than the screen — so pinning
        // both leading AND trailing makes the layout unsatisfiable. UIKit then breaks
        // a `width == 115` constraint on every layout pass, and during the burst of
        // diffable `apply(...)` calls at launch that re-solving thrashes the main
        // thread (the console flood + frozen Home screen). Letting the row overflow
        // to the right — exactly like the real horizontally-scrolling cards — keeps
        // the constraints satisfiable.
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let barWidth = Layout.posterCardWidth(for: traitCollection)
        for _ in 0..<5 {
            let v = UIView()
            v.layer.cornerRadius = 14
            let w = v.widthAnchor.constraint(equalToConstant: barWidth)
            w.isActive = true
            barWidthConstraints.append(w)
            stack.addArrangedSubview(v)
        }
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.horizontalSizeClass != previous?.horizontalSizeClass {
            let barWidth = Layout.posterCardWidth(for: traitCollection)
            barWidthConstraints.forEach { $0.constant = barWidth }
        }
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        stack.arrangedSubviews.forEach { $0.backgroundColor = theme.shimmerColor }
    }

    func startAnimating() {
        isHidden = false
        stack.arrangedSubviews.enumerated().forEach { idx, v in
            let a = CABasicAnimation(keyPath: "opacity")
            a.fromValue = 0.4; a.toValue = 0.9; a.duration = 0.9
            a.autoreverses = true; a.repeatCount = .infinity
            a.beginTime = CACurrentMediaTime() + Double(idx) * 0.12
            v.layer.add(a, forKey: "shimmer")
        }
    }
    func stopAnimating() {
        isHidden = true
        stack.arrangedSubviews.forEach { $0.layer.removeAllAnimations() }
    }
}
