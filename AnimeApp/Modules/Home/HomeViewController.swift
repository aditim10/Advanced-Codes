//
//  HomeViewController.swift
//  AnimeApp
//
//  The VIP **View** for Home. It is deliberately "dumb": it renders the snapshot
//  the Presenter gives it (driving a diffable data source) and forwards user
//  intent to the Interactor / Router. No networking, no formatting, no paging
//  math — all of that lives in the Interactor and Presenter.
//

import UIKit

// MARK: - Display boundary

@MainActor
protocol HomeDisplayLogic: AnyObject {
    func displayLoading()
    func displaySnapshot(_ viewModel: Home.ViewModel)
    func displayError(_ message: String)
}

final class HomeViewController: UIViewController, HomeDisplayLogic {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView:        UITableView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var navBarView:       UIView!
    @IBOutlet weak var logoLabel:        UILabel!
    @IBOutlet weak var searchButton:     UIButton!
    @IBOutlet weak var profileButton:    UIButton!

    // MARK: - VIP collaborators
    var interactor: HomeBusinessLogic?
    var router: (HomeRoutingLogic & HomeDataPassing)?

    // MARK: - Diffable data source
    private enum TableSection { case main }
    private var dataSource: UITableViewDiffableDataSource<TableSection, Home.Row>!

    /// Ids of the banners currently shown, so we only rebuild/reconfigure the
    /// banner carousel (and restart its auto-scroll timer) when they actually
    /// change — not on every snapshot the Interactor emits during loading.
    private var shownBannerIDs: [Int] = []

    private lazy var bannerContainer: BannerView = {
        let banner = BannerView()
        banner.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 400)
        banner.onSelect = { [weak self] animeID in self?.router?.routeToDetail(animeID: animeID) }
        return banner
    }()

    // MARK: - Init / VIP setup (storyboard-instantiated → init?(coder:))

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Wires the View ↔ Interactor ↔ Presenter ↔ Router graph.
    private func setup() {
        let interactor = HomeInteractor()
        let presenter = HomePresenter()
        let router = HomeRouter()

        interactor.presenter = presenter
        presenter.viewController = self
        router.viewController = self
        router.dataStore = interactor

        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureDataSource()
        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
        interactor?.loadInitial(request: Home.Load.Request())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup
    private func setupUI() {
        navigationController?.setNavigationBarHidden(true, animated: false)

        tableView.separatorStyle  = .none
        tableView.contentInset    = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.tableHeaderView = bannerContainer
        tableView.delegate        = self
        tableView.register(SectionRowCell.self, forCellReuseIdentifier: SectionRowCell.id)

        loadingIndicator.hidesWhenStopped = true

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refresh
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<TableSection, Home.Row>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, row in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SectionRowCell.id, for: indexPath) as! SectionRowCell
            cell.configure(title: row.title, cards: row.cards, isLoading: row.isLoading)
            cell.onCardSelected = { [weak self] animeID in self?.router?.routeToDetail(animeID: animeID) }
            cell.onSeeAll       = { [weak self] in self?.router?.routeToSeeAll(genreID: row.id) }
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    // MARK: - HomeDisplayLogic

    func displayLoading() {
        if bannerContainer.isEmpty { loadingIndicator.startAnimating() }
    }

    func displaySnapshot(_ viewModel: Home.ViewModel) {
        loadingIndicator.stopAnimating()
        tableView.refreshControl?.endRefreshing()

        // Only rebuild the banner when its contents actually change. The Interactor
        // emits several snapshots while loading; reconfiguring on each one needlessly
        // reloaded the carousel and restarted its auto-scroll timer every time.
        let bannerIDs = viewModel.banners.map(\.id)
        if bannerIDs != shownBannerIDs {
            shownBannerIDs = bannerIDs
            bannerContainer.configure(with: viewModel.banners)
        }

        var snapshot = NSDiffableDataSourceSnapshot<TableSection, Home.Row>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.rows, toSection: .main)
        // animatingDifferences: false — Home re-emits a full authoritative snapshot
        // on every load step, and `Home.Row` is identified by its full contents, so
        // each change is a delete+insert. Animating those stacked rebuilds (each of
        // which reloads a nested collection view) thrashed the main thread. A
        // non-animated apply updates in one pass with no overlapping animations.
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func displayError(_ message: String) {
        loadingIndicator.stopAnimating()
        tableView.refreshControl?.endRefreshing()
        let alert = UIAlertController(title: AppStrings.Common.oops, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.Common.retry, style: .default) { [weak self] _ in
            self?.interactor?.loadInitial(request: Home.Load.Request())
        })
        alert.addAction(UIAlertAction(title: AppStrings.Common.ok, style: .cancel))
        present(alert, animated: true)
    }

    /// Called by the Router after a theme change so the View re-applies colours.
    func refreshTheme() { applyTheme() }

    // MARK: - Theme
    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current

        view.backgroundColor       = theme.background
        tableView.backgroundColor  = theme.background

        navBarView.backgroundColor     = theme.navBarBackground
        navBarView.layer.shadowColor   = theme.accentPrimary.withAlphaComponent(0.1).cgColor
        navBarView.layer.shadowOpacity = 1
        navBarView.layer.shadowRadius  = 8
        navBarView.layer.shadowOffset  = CGSize(width: 0, height: 2)

        logoLabel.text            = AppStrings.Home.brand
        logoLabel.font            = .systemFont(ofSize: 26, weight: .black)
        logoLabel.textColor       = theme.accentPrimary
        logoLabel.backgroundColor = .clear
        logoLabel.isOpaque        = false

        searchButton.setImage(
            UIImage(systemName: "magnifyingglass",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)),
            for: .normal)
        searchButton.tintColor = theme.accentPrimary

        profileButton.setImage(
            UIImage(systemName: "person.circle.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)),
            for: .normal)
        profileButton.tintColor = theme.accentPrimary

        loadingIndicator.color = theme.accentPrimary
        tableView.refreshControl?.tintColor = theme.accentPrimary

        setNeedsStatusBarAppearanceUpdate()
        // Don't call tableView.reloadData() here: the table is driven by a diffable
        // data source (reloadData desyncs its snapshot), and every cell already
        // re-applies the theme itself via its ThemeManager.didChangeTheme observer.
    }

    // MARK: - IBActions
    @IBAction func searchTapped(_ sender: UIButton) {
        router?.routeToSearch()
    }

    @IBAction func profileTapped(_ sender: UIButton) {
        router?.presentProfileMenu(from: sender)
    }

    @objc private func handleRefresh() {
        interactor?.refresh()
    }
}

// MARK: - UITableViewDelegate (data source is diffable)
extension HomeViewController: UITableViewDelegate {

    func tableView(_ tv: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Layout.sectionRowHeight
    }

    // Infinite scroll: ask the Interactor for more rows as the user nears the bottom.
    func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let total = dataSource.snapshot().numberOfItems
        guard total > 0, indexPath.row >= total - Layout.paginationPrefetchDistance else { return }
        interactor?.loadMore(request: Home.Paginate.Request())
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        let alpha  = min(1, max(0, offset / 60))
        navBarView.layer.shadowOpacity = Float(alpha * 0.15)
    }
}
