//
//  SeeAllViewController.swift
//  AnimeApp
//
//  VIP View for the "See all" genre grid. Driven by a diffable data source;
//  fetching/paging/analytics live in the Interactor. Pushed from a Home row's
//  "See all" button via `init(title:genreID:)`.
//

import UIKit

@MainActor
protocol SeeAllDisplayLogic: AnyObject {
    func display(_ viewModel: SeeAll.ViewModel)
}

final class SeeAllViewController: UIViewController, SeeAllDisplayLogic {

    // MARK: - VIP collaborators
    var interactor: SeeAllBusinessLogic?
    var router: (SeeAllRoutingLogic & SeeAllDataPassing)?

    // MARK: - UI
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 18
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = true
        collection.showsVerticalScrollIndicator = false
        collection.register(AnimeCardCell.self, forCellWithReuseIdentifier: AnimeCardCell.id)
        collection.delegate = self
        collection.translatesAutoresizingMaskIntoConstraints = false
        return collection
    }()

    // MARK: - Diffable data source
    private enum GridSection { case main }
    private var dataSource: UICollectionViewDiffableDataSource<GridSection, SeeAll.Item>!

    // MARK: - Init / VIP setup
    init(title: String, genreID: Int) {
        super.init(nibName: nil, bundle: nil)
        setup(title: title, genreID: genreID)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setup(title: String, genreID: Int) {
        let interactor = SeeAllInteractor(title: title, genreID: genreID)
        let presenter = SeeAllPresenter()
        let router = SeeAllRouter()

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
        interactor?.loadInitial(request: SeeAll.Load.Request())
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup
    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<GridSection, SeeAll.Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AnimeCardCell.id, for: indexPath) as! AnimeCardCell
            cell.configure(with: item)
            return cell
        }
    }

    // MARK: - Theme
    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        view.backgroundColor = theme.background
        loadingIndicator.color = theme.accentPrimary
        collectionView.reloadData()
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - SeeAllDisplayLogic
    func display(_ viewModel: SeeAll.ViewModel) {
        switch viewModel.status {
        case .loading where viewModel.items.isEmpty:
            loadingIndicator.startAnimating()
        case .loading:
            break
        case .loaded:
            loadingIndicator.stopAnimating()
        case .error(let message):
            loadingIndicator.stopAnimating()
            presentError(message)
        }

        var snapshot = NSDiffableDataSourceSnapshot<GridSection, SeeAll.Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: AppStrings.Common.oops, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.Common.ok, style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionView delegate / layout (data source is diffable)
extension SeeAllViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        interactor?.loadMore(request: SeeAll.Paginate.Request(currentIndex: indexPath.item))
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        router?.routeToDetail(animeID: item.id)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Adaptive column count (3 on iPhone, more on wider iPad/landscape layouts),
        // with 16pt outer insets and 12pt gutters. The flow layout re-invalidates on
        // width change, so the grid reflows on rotation and split-view resize.
        let columns = CGFloat(Layout.gridColumns(forWidth: collectionView.bounds.width))
        let totalSpacing: CGFloat = 16 * 2 + 12 * (columns - 1)
        let width = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: width, height: width * 1.9)
    }
}
