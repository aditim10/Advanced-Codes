//
//  SeeAllInteractor.swift
//  AnimeApp
//
//  VIP Interactor for the "See all" grid: a single genre's full, paginated
//  catalogue with infinite scroll + analytics. UIKit-free.
//

import Foundation
import ConcurrentAPI
import AnalyticsKit

@MainActor
protocol SeeAllBusinessLogic {
    var sectionTitle: String { get }
    func loadInitial(request: SeeAll.Load.Request)
    func loadMore(request: SeeAll.Paginate.Request)
}

@MainActor
protocol SeeAllDataStore {
    func anime(withID id: Int) -> Anime?
}

@MainActor
final class SeeAllInteractor: SeeAllBusinessLogic, SeeAllDataStore {

    var presenter: SeeAllPresentationLogic?

    let sectionTitle: String
    private let genreID: Int
    private let service: GenreAnimeServicing
    private let analytics: AnalyticsManager

    private var items: [Anime] = []
    private var currentPage = 0
    private var hasNextPage = true
    private var isLoadingPage = false

    init(
        title: String,
        genreID: Int,
        service: GenreAnimeServicing = GenreAnimeService(),
        analytics: AnalyticsManager = .shared
    ) {
        self.sectionTitle = title
        self.genreID = genreID
        self.service = service
        self.analytics = analytics
    }

    // MARK: SeeAllDataStore

    func anime(withID id: Int) -> Anime? {
        items.first { $0.malID == id }
    }

    // MARK: SeeAllBusinessLogic

    func loadInitial(request: SeeAll.Load.Request) {
        guard items.isEmpty else { return }
        analytics.emit(SeeAllAnalyticsEvent.open(section: sectionTitle))
        present(.loading)
        Task { await loadNextPage() }
    }

    func loadMore(request: SeeAll.Paginate.Request) {
        guard hasNextPage, !isLoadingPage else { return }
        guard request.currentIndex >= items.count - Layout.paginationPrefetchDistance else { return }
        Task { await loadNextPage() }
    }

    // MARK: - Private

    private func loadNextPage() async {
        guard hasNextPage, !isLoadingPage else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        let nextPage = currentPage + 1
        if nextPage > 1 {
            analytics.emit(SeeAllAnalyticsEvent.paginate(section: sectionTitle, page: nextPage))
        }

        do {
            let page = try await service.anime(
                genreID: genreID, page: nextPage, limit: APIConstants.gridPageSize)
            items += page.items
            currentPage = page.currentPage
            hasNextPage = page.hasNextPage
            present(.loaded)
        } catch {
            if case APIError.cancelled = error { return }
            present(.error(error.localizedDescription))
        }
    }

    private func present(_ status: SeeAll.Response.Status) {
        presenter?.present(response: SeeAll.Response(status: status, items: items))
    }
}
