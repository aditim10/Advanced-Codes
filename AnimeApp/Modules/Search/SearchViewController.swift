//
//  SearchViewController.swift
//  AnimeApp
//
//  VIP View for Search: a debounced, paginated results list driven by a diffable
//  data source. Fetching/paging/analytics live in the Interactor.
//

import UIKit

@MainActor
protocol SearchDisplayLogic: AnyObject {
    func display(_ viewModel: Search.ViewModel)
}

final class SearchViewController: UIViewController, SearchDisplayLogic {

    // MARK: - UI
    private let headerView = UIView()
    private let searchField = UISearchTextField()
    private let cancelButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private let emptyStateView = UIView()
    private let emptyIcon = UILabel()
    private let emptyTitle = UILabel()
    private let emptySubtitle = UILabel()

    // MARK: - VIP collaborators
    var interactor: SearchBusinessLogic?
    var router: (SearchRoutingLogic & SearchDataPassing)?

    // MARK: - Diffable data source
    private enum TableSection { case main }
    private var dataSource: UITableViewDiffableDataSource<TableSection, Search.Item>!

    private var debounceTask: Task<Void, Never>?
    private let debounceNanos: UInt64 = 350_000_000

    // MARK: - Init / VIP setup
    init() {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let interactor = SearchInteractor()
        let presenter = SearchPresenter()
        let router = SearchRouter()

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
        showEmptyState(state: .idle)
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchField.becomeFirstResponder()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup
    private func setupUI() {
        navigationController?.setNavigationBarHidden(true, animated: false)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholder = AppStrings.Search.placeholder
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        headerView.addSubview(searchField)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(AppStrings.Common.cancel, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        headerView.addSubview(cancelButton)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 104
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.id)
        tableView.delegate = self
        view.addSubview(tableView)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        setupEmptyState()

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),

            cancelButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            cancelButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 40),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 60),
        ])
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<TableSection, Search.Item>(
            tableView: tableView
        ) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SearchResultCell.id, for: indexPath) as! SearchResultCell
            cell.configure(with: item)
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        emptyIcon.font = .systemFont(ofSize: 52)
        emptyIcon.textAlignment = .center
        emptyTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        emptyTitle.textAlignment = .center
        emptySubtitle.font = .systemFont(ofSize: 13)
        emptySubtitle.textAlignment = .center
        emptySubtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [emptyIcon, emptyTitle, emptySubtitle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(stack)

        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            emptyStateView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
        ])
    }

    // MARK: - Theme
    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current

        view.backgroundColor       = theme.background
        headerView.backgroundColor = theme.navBarBackground
        tableView.backgroundColor  = theme.background
        cancelButton.tintColor     = theme.accentPrimary
        loadingIndicator.color     = theme.accentPrimary

        searchField.backgroundColor = theme.cardBackground
        searchField.textColor       = theme.bodyText
        searchField.tintColor       = theme.accentPrimary
        searchField.leftView?.tintColor = theme.secondaryText
        searchField.attributedPlaceholder = NSAttributedString(
            string: AppStrings.Search.placeholder,
            attributes: [.foregroundColor: theme.secondaryText])
        searchField.layer.cornerRadius = 12
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = theme.accentPrimary.withAlphaComponent(0.18).cgColor

        emptyTitle.textColor    = theme.bodyText
        emptySubtitle.textColor = theme.secondaryText

        setNeedsStatusBarAppearanceUpdate()
        tableView.reloadData()
    }

    // MARK: - Empty / result states
    private enum EmptyState { case idle, noResults, hidden }

    private func showEmptyState(state: EmptyState) {
        switch state {
        case .idle:
            emptyIcon.text = "🔍"
            emptyTitle.text = AppStrings.Search.discoverTitle
            emptySubtitle.text = AppStrings.Search.discoverSubtitle
            emptyStateView.isHidden = false
        case .noResults:
            emptyIcon.text = "🫥"
            emptyTitle.text = AppStrings.Search.noResultsTitle
            emptySubtitle.text = AppStrings.Search.noResultsSubtitle
            emptyStateView.isHidden = false
        case .hidden:
            emptyStateView.isHidden = true
        }
    }

    // MARK: - SearchDisplayLogic
    func display(_ viewModel: Search.ViewModel) {
        switch viewModel.status {
        case .idle:
            loadingIndicator.stopAnimating()
            showEmptyState(state: .idle)
        case .loading:
            if viewModel.items.isEmpty { loadingIndicator.startAnimating() }
            showEmptyState(state: .hidden)
        case .results:
            loadingIndicator.stopAnimating()
            showEmptyState(state: .hidden)
        case .empty:
            loadingIndicator.stopAnimating()
            showEmptyState(state: .noResults)
        }

        var snapshot = NSDiffableDataSourceSnapshot<TableSection, Search.Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - Search input (debounced)
    @objc private func textChanged() {
        let query = searchField.text ?? ""
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceNanos)
            guard !Task.isCancelled else { return }
            self.interactor?.search(request: Search.Query.Request(text: query))
        }
    }

    @objc private func cancelTapped() {
        searchField.resignFirstResponder()
        interactor?.cancel()
        router?.dismiss()
    }
}

// MARK: - UITextFieldDelegate
extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDelegate (data source is diffable)
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        interactor?.loadMore(request: Search.Paginate.Request(currentIndex: indexPath.row))
    }

    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        router?.routeToDetail(animeID: item.id)
    }
}

// MARK: - SearchResultCell
final class SearchResultCell: UITableViewCell {
    static let id = "SearchResultCell"

    private let posterView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let scoreLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let card = UIView()

    private var imageTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        card.addSubview(posterView)
        card.addSubview(titleLabel)
        card.addSubview(scoreLabel)
        card.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            posterView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            posterView.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            posterView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            posterView.widthAnchor.constraint(equalToConstant: 56),

            titleLabel.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),

            scoreLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            scoreLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),

            metaLabel.leadingAnchor.constraint(equalTo: scoreLabel.trailingAnchor, constant: 10),
            metaLabel.centerYAnchor.constraint(equalTo: scoreLabel.centerYAnchor),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        card.backgroundColor       = theme.cardBackground
        posterView.backgroundColor = theme.shimmerColor
        titleLabel.textColor       = theme.bodyText
        metaLabel.textColor        = theme.secondaryText
        scoreLabel.textColor       = theme.amberScore
    }

    func configure(with item: AnimeCardDisplaying) {
        applyTheme()
        titleLabel.text = item.cardTitle
        scoreLabel.text = "⭐ \(item.cardScore)"
        metaLabel.text  = item.cardMeta

        posterView.image = nil
        imageTask?.cancel()
        if let url = item.cardPosterURL {
            imageTask = Task { [weak self] in
                if let img = await ImageLoader.shared.image(from: url) {
                    await MainActor.run { self?.posterView.image = img }
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        posterView.image = nil
    }
}
