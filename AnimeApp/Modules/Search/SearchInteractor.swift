//
//  SearchInteractor.swift
//  AnimeApp
//
//  VIP Interactor for Search: owns query state, paging, and analytics. UIKit-free.
//

import Foundation
import ConcurrentAPI

@MainActor
protocol SearchBusinessLogic {
    func search(request: Search.Query.Request)
    func loadMore(request: Search.Paginate.Request)
    func cancel()
}

@MainActor
protocol SearchDataStore {
    func anime(withID id: Int) -> Anime?
}

@MainActor
final class SearchInteractor: SearchBusinessLogic, SearchDataStore {

    var presenter: SearchPresentationLogic?

    private let service: AnimeSearchServicing
    private let analytics: AnalyticsManager

    private var results: [Anime] = []
    private var currentQuery = ""
    private var currentPage = 1
    private var hasNextPage = false
    private var isLoadingPage = false
    private var activeTask: Task<Void, Never>?

    init(
        service: AnimeSearchServicing = AnimeSearchService(),
        analytics: AnalyticsManager = .shared
    ) {
        self.service = service
        self.analytics = analytics
    }

    // MARK: SearchDataStore

    func anime(withID id: Int) -> Anime? {
        results.first { $0.malID == id }
    }

    // MARK: SearchBusinessLogic

    func search(request: Search.Query.Request) {
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        activeTask?.cancel()

        guard !trimmed.isEmpty else {
            currentQuery = ""
            results = []
            present(.idle)
            return
        }

        currentQuery = trimmed
        analytics.publish(SearchAnalyticsEvent.query(trimmed))
        present(.loading)
        activeTask = Task { await loadPage(reset: true) }
    }

    func loadMore(request: Search.Paginate.Request) {
        guard hasNextPage, !isLoadingPage, !currentQuery.isEmpty else { return }
        guard request.currentIndex >= results.count - Layout.paginationPrefetchDistance else { return }
        activeTask = Task { await loadPage(reset: false) }
    }

    func cancel() { activeTask?.cancel() }

    // MARK: - Private

    private func loadPage(reset: Bool) async {
        guard !isLoadingPage else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        let page = reset ? 1 : currentPage + 1
        if !reset {
            analytics.publish(SearchAnalyticsEvent.paginate(query: currentQuery, page: page))
        }

        do {
            let result = try await service.search(
                query: currentQuery, page: page, limit: APIConstants.gridPageSize
            )
            if Task.isCancelled { return }

            if reset { results = result.items } else { results += result.items }
            currentPage = result.currentPage
            hasNextPage = result.hasNextPage

            analytics.publish(
                SearchAnalyticsEvent.resultSuccess(query: currentQuery, count: result.items.count))
            present(results.isEmpty ? .empty : .results)
        } catch {
            if Task.isCancelled { return }
            if case APIError.cancelled = error { return }

            analytics.publish(
                SearchAnalyticsEvent.resultFailure(query: currentQuery, reason: error.localizedDescription))
            if reset {
                results = []
                present(.empty)
            }
        }
    }

    private func present(_ status: Search.Response.Status) {
        presenter?.present(response: Search.Response(status: status, items: results))
    }
}
