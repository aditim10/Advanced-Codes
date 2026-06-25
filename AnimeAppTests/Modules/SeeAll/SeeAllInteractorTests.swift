//
//  SeeAllInteractorTests.swift
//  AnimeAppTests
//
//  Covers the "See all" VIP Interactor: initial page load, the open analytics
//  event, and the error path.
//

import XCTest
import AnalyticsKit
@testable import AnimeApp

@MainActor
final class SpySeeAllPresenter: SeeAllPresentationLogic {
    private(set) var responses: [SeeAll.Response] = []
    var onResponse: ((SeeAll.Response) -> Void)?

    func present(response: SeeAll.Response) {
        responses.append(response)
        onResponse?(response)
    }
}

@MainActor
final class SeeAllInteractorTests: XCTestCase {

    func testLoadInitialLoadsFirstPageAndFiresOpenEvent() async {
        let bus = AnalyticsManager(delivery: .synchronous)
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        let service = MockGenreService(
            pages: [AnimePage(items: Sample.animeList(count: 8), currentPage: 1, hasNextPage: true)])
        let interactor = SeeAllInteractor(title: "Action", genreID: 1, service: service, analytics: bus)
        let presenter = SpySeeAllPresenter()
        interactor.presenter = presenter

        let loaded = expectation(description: "loaded")
        loaded.assertForOverFulfill = false
        presenter.onResponse = { response in
            if case .loaded = response.status, response.items.count == 8 { loaded.fulfill() }
        }

        interactor.loadInitial(request: SeeAll.Load.Request())
        await fulfillment(of: [loaded], timeout: 2)

        XCTAssertEqual(presenter.responses.last?.items.count, 8)
        XCTAssertEqual(service.requestedPages.first, 1)
        XCTAssertTrue(spy.contains("see_all_open"))
    }

    func testErrorReportsErrorState() async {
        let service = MockGenreService(pages: [], error: TestError.boom)
        let interactor = SeeAllInteractor(title: "Action", genreID: 1,
                                          service: service, analytics: AnalyticsManager(delivery: .synchronous))
        let presenter = SpySeeAllPresenter()
        interactor.presenter = presenter

        let sawError = expectation(description: "error")
        sawError.assertForOverFulfill = false
        presenter.onResponse = { response in
            if case .error = response.status { sawError.fulfill() }
        }

        interactor.loadInitial(request: SeeAll.Load.Request())
        await fulfillment(of: [sawError], timeout: 2)

        XCTAssertEqual(presenter.responses.last?.items.count, 0)
    }
}
