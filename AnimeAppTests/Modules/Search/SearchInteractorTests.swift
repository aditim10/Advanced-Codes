//
//  SearchInteractorTests.swift
//  AnimeAppTests
//
//  Covers the Search VIP Interactor: results, the empty-query short-circuit,
//  analytics, and the failure path. Search runs on a detached Task internally,
//  so the tests drive it through the spy Presenter using an expectation.
//

import XCTest
import AnalyticsKit
@testable import AnimeApp

@MainActor
final class SpySearchPresenter: SearchPresentationLogic {
    private(set) var responses: [Search.Response] = []
    var onResponse: ((Search.Response) -> Void)?

    func present(response: Search.Response) {
        responses.append(response)
        onResponse?(response)
    }
}

@MainActor
final class SearchInteractorTests: XCTestCase {

    func testSuccessfulSearchPublishesResults() async {
        let bus = AnalyticsManager(delivery: .synchronous)
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        let service = MockSearchService(
            pages: [AnimePage(items: Sample.animeList(count: 6), currentPage: 1, hasNextPage: false)])
        let interactor = SearchInteractor(service: service, analytics: bus)
        let presenter = SpySearchPresenter()
        interactor.presenter = presenter

        let resultsShown = expectation(description: "results reached")
        resultsShown.assertForOverFulfill = false
        presenter.onResponse = { response in
            if case .results = response.status { resultsShown.fulfill() }
        }

        interactor.search(request: Search.Query.Request(text: "bleach"))
        await fulfillment(of: [resultsShown], timeout: 2)

        XCTAssertEqual(presenter.responses.last?.items.count, 6)
        XCTAssertEqual(service.queries, ["bleach"])
        XCTAssertTrue(spy.contains("search_query"))
        XCTAssertTrue(spy.contains("search_result_success"))
    }

    func testEmptyQueryGoesIdleWithoutHittingService() {
        let service = MockSearchService(pages: [])
        let interactor = SearchInteractor(service: service, analytics: AnalyticsManager(delivery: .synchronous))
        let presenter = SpySearchPresenter()
        interactor.presenter = presenter

        interactor.search(request: Search.Query.Request(text: "   "))

        if case .idle = presenter.responses.last?.status {} else {
            XCTFail("Expected idle status for an empty query")
        }
        XCTAssertTrue(service.queries.isEmpty, "Service must not be called for empty query")
    }

    func testFailedSearchFiresFailureAndShowsEmpty() async {
        let bus = AnalyticsManager(delivery: .synchronous)
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        let service = MockSearchService(pages: [], error: TestError.boom)
        let interactor = SearchInteractor(service: service, analytics: bus)
        let presenter = SpySearchPresenter()
        interactor.presenter = presenter

        let emptyShown = expectation(description: "empty reached")
        emptyShown.assertForOverFulfill = false
        presenter.onResponse = { response in
            if case .empty = response.status { emptyShown.fulfill() }
        }

        interactor.search(request: Search.Query.Request(text: "zzz"))
        await fulfillment(of: [emptyShown], timeout: 2)

        XCTAssertEqual(presenter.responses.last?.items.count, 0)
        XCTAssertTrue(spy.contains("search_result_failure"))
    }
}
