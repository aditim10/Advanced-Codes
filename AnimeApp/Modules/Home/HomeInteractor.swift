//
//  HomeInteractor.swift
//  AnimeApp
//
//  The VIP **Interactor** for Home: it owns all business logic and state —
//  fetching the featured banner and genre rows, throttled batch loading, and
//  infinite-scroll pagination. It never touches UIKit; it hands raw domain data
//  to the Presenter, which turns it into a dumb snapshot for the View.
//
//  It also doubles as the module's `HomeDataStore`, so the Router can resolve the
//  domain object behind a tapped card without the View ever seeing a model.
//

import Foundation

// MARK: - Boundaries

/// What the View is allowed to ask Home to do.
@MainActor
protocol HomeBusinessLogic {
    func loadInitial(request: Home.Load.Request)
    func refresh()
    func loadMore(request: Home.Paginate.Request)
}

/// Data the Router reads to navigate (kept separate from business logic).
@MainActor
protocol HomeDataStore {
    func anime(withID id: Int) -> Anime?
    func section(withGenreID id: Int) -> AnimeSection?
}

// MARK: - HomeInteractor

@MainActor
final class HomeInteractor: HomeBusinessLogic, HomeDataStore {

    var presenter: HomePresentationLogic?

    // Dependencies
    private let featuredService: FeaturedAnimeServicing
    private let genreService: GenreAnimeServicing
    private let analytics: AnalyticsManager

    // Domain state (the single source of truth for the screen)
    private var featured: [Anime] = []
    private var sections: [AnimeSection] = []

    // Paging cursor
    private let allGenres: [AnimeGenre] = AnimeGenre.allCases
    private var nextGenreIndex = 0
    private var isLoadingMore = false
    private var initialLoadComplete = false
    private let initialSectionCount = 4
    private let pageSectionCount = 2
    private var loadTask: Task<Void, Never>?

    init(
        featuredService: FeaturedAnimeServicing = FeaturedAnimeService(),
        genreService: GenreAnimeServicing = GenreAnimeService(),
        analytics: AnalyticsManager = .shared
    ) {
        self.featuredService = featuredService
        self.genreService = genreService
        self.analytics = analytics
    }

    // MARK: HomeBusinessLogic

    func loadInitial(request: Home.Load.Request) {
        guard sections.isEmpty else { return }
        loadTask?.cancel()
        loadTask = Task { await performInitialLoad() }
    }

    func refresh() {
        featured = []
        sections = []
        nextGenreIndex = 0
        isLoadingMore = false
        initialLoadComplete = false
        loadTask?.cancel()
        loadTask = Task { await performInitialLoad() }
    }

    func loadMore(request: Home.Paginate.Request) {
        // Don't paginate until the initial rows have finished loading, otherwise
        // the first on-screen rows trigger extra genre fetches mid-launch and
        // compound Jikan's rate limiting (429s → empty/slow rows).
        guard initialLoadComplete else { return }
        Task { await performLoadMore() }
    }

    // MARK: HomeDataStore

    func anime(withID id: Int) -> Anime? {
        if let hit = featured.first(where: { $0.malID == id }) { return hit }
        for section in sections {
            if let hit = section.anime.first(where: { $0.malID == id }) { return hit }
        }
        return nil
    }

    func section(withGenreID id: Int) -> AnimeSection? {
        sections.first { $0.genreID == id }
    }

    // MARK: - Work

    private func performInitialLoad() async {
        presenter?.presentLoading()

        // Populate placeholder rows FIRST so the screen is immediately filled and
        // scrollable. The banner network call must never gate the rows appearing —
        // otherwise a slow/rate-limited response leaves Home empty and unscrollable.
        let firstBatch = min(initialSectionCount, allGenres.count)
        for _ in 0..<firstBatch { appendNextGenrePlaceholder() }
        presentSnapshot()                       // show shimmer rows immediately

        // Banner is non-fatal; load it, then fill the row content.
        await loadFeatured()

        await fillSections(at: Array(0..<sections.count))

        initialLoadComplete = true
        analytics.publish(HomeAnalyticsEvent.loadSuccess(sectionCount: sections.count))
        presentSnapshot()
    }

    private func performLoadMore() async {
        guard nextGenreIndex < allGenres.count, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let startIndex = sections.count
        let batch = min(pageSectionCount, allGenres.count - nextGenreIndex)
        guard batch > 0 else { return }

        for _ in 0..<batch { appendNextGenrePlaceholder() }
        presentSnapshot()                       // shimmer placeholders for the new rows

        analytics.publish(HomeAnalyticsEvent.paginate(page: pageNumber(forSectionIndex: startIndex)))

        await fillSections(at: Array(startIndex..<sections.count))
        presentSnapshot()
    }

    private func loadFeatured() async {
        do {
            featured = try await featuredService.topAnime(limit: APIConstants.bannerLimit)
            presentSnapshot()
        } catch {
            // Non-fatal: the rows still work without the banner.
            analytics.publish(HomeAnalyticsEvent.loadFailure(reason: error.localizedDescription))
        }
    }

    /// Fills sections in small concurrent batches so we don't burst the
    /// rate-limited Jikan API (which returned 429s and left rows empty on
    /// launch). Each completed batch is presented so rows fill in progressively.
    private func fillSections(at indices: [Int]) async {
        for batchStart in stride(from: 0, to: indices.count, by: APIConstants.maxConcurrentLoads) {
            let batch = Array(indices[batchStart..<min(batchStart + APIConstants.maxConcurrentLoads, indices.count)])

            await withTaskGroup(of: (Int, [Anime]).self) { group in
                for index in batch {
                    guard sections.indices.contains(index) else { continue }
                    let genreID = sections[index].genreID
                    group.addTask { [genreService] in
                        let page = try? await genreService.anime(
                            genreID: genreID, page: 1, limit: APIConstants.rowPageSize
                        )
                        return (index, page?.items ?? [])
                    }
                }
                for await (index, anime) in group where sections.indices.contains(index) {
                    sections[index].anime = anime
                    sections[index].isLoading = false
                }
            }
            presentSnapshot()
        }
    }

    private func appendNextGenrePlaceholder() {
        guard nextGenreIndex < allGenres.count else { return }
        let genre = allGenres[nextGenreIndex]
        nextGenreIndex += 1
        sections.append(
            AnimeSection(title: genre.sectionTitle, genreID: genre.rawValue, anime: [], isLoading: true)
        )
    }

    private func pageNumber(forSectionIndex index: Int) -> Int {
        (index / max(1, pageSectionCount)) + 1
    }

    private func presentSnapshot() {
        presenter?.presentSnapshot(response: Home.Load.Response(featured: featured, rows: sections))
    }
}
