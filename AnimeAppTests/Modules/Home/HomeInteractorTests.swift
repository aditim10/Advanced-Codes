//
//  HomeInteractorTests.swift
//  AnimeAppTests
//
//  Verifies the Home VIP Interactor: initial load (featured + first batch of
//  rows), analytics, and infinite-scroll pagination. A spy Presenter captures
//  the responses the Interactor emits; mock services keep it off the network.
//

import XCTest
import AnalyticsKit
@testable import AnimeApp

// MARK: - Spy presenter

@MainActor
final class SpyHomePresenter: HomePresentationLogic {
    private(set) var didPresentLoading = false
    private(set) var lastResponse: Home.Load.Response?
    private(set) var snapshotCount = 0
    private(set) var lastError: String?
    var onSnapshot: ((Home.Load.Response) -> Void)?
    var onError: ((String) -> Void)?

    func presentLoading() { didPresentLoading = true }

    func presentSnapshot(response: Home.Load.Response) {
        snapshotCount += 1
        lastResponse = response
        onSnapshot?(response)
    }

    func presentError(_ message: String) {
        lastError = message
        onError?(message)
    }
}

@MainActor
final class HomeInteractorTests: XCTestCase {

    private func makeInteractor(
        featured: [Anime] = Sample.animeList(count: 5),
        genrePage: AnimePage = AnimePage(items: Sample.animeList(count: 10), currentPage: 1, hasNextPage: true),
        featuredError: Error? = nil
    ) -> (HomeInteractor, SpyHomePresenter, SpyAnalyticsProvider) {
        let bus = AnalyticsManager(delivery: .synchronous)
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        let interactor = HomeInteractor(
            featuredService: MockFeaturedService(result: featured, error: featuredError),
            genreService: MockGenreService(pages: [genrePage]),
            analytics: bus
        )
        let presenter = SpyHomePresenter()
        interactor.presenter = presenter
        return (interactor, presenter, spy)
    }

    /// Waits until the presenter receives a snapshot whose first batch of rows
    /// has finished loading.
    private func waitForLoadedRows(_ presenter: SpyHomePresenter, count: Int) async {
        let exp = expectation(description: "rows loaded")
        exp.assertForOverFulfill = false
        presenter.onSnapshot = { response in
            if response.rows.count >= count, response.rows.prefix(count).allSatisfy({ !$0.isLoading }) {
                exp.fulfill()
            }
        }
        await fulfillment(of: [exp], timeout: 2)
    }

    func testLoadInitialPopulatesFeaturedAndRows() async {
        let (interactor, presenter, spy) = makeInteractor()

        interactor.loadInitial(request: Home.Load.Request())
        await waitForLoadedRows(presenter, count: 4)

        XCTAssertEqual(presenter.lastResponse?.featured.count, 5)
        XCTAssertEqual(presenter.lastResponse?.rows.count, 4, "Initial batch should be 4 rows")
        XCTAssertFalse(presenter.lastResponse?.rows.first?.anime.isEmpty ?? true)
        XCTAssertTrue(spy.contains("home_load_success"))
    }

    func testLoadInitialIsIdempotent() async {
        let (interactor, presenter, _) = makeInteractor()

        interactor.loadInitial(request: Home.Load.Request())
        await waitForLoadedRows(presenter, count: 4)
        let firstCount = presenter.lastResponse?.rows.count

        interactor.loadInitial(request: Home.Load.Request())   // should no-op
        XCTAssertEqual(presenter.lastResponse?.rows.count, firstCount)
    }

    func testPaginationAppendsMoreRowsAndFiresEvent() async {
        let (interactor, presenter, spy) = makeInteractor()
        interactor.loadInitial(request: Home.Load.Request())
        await waitForLoadedRows(presenter, count: 4)
        let before = presenter.lastResponse?.rows.count ?? 0

        interactor.loadMore(request: Home.Paginate.Request())
        await waitForLoadedRows(presenter, count: before + 1)

        XCTAssertGreaterThan(presenter.lastResponse?.rows.count ?? 0, before)
        XCTAssertTrue(spy.contains("home_paginate"))
    }

    func testFeaturedFailureStillLoadsRowsAndFiresFailure() async {
        let (interactor, presenter, spy) = makeInteractor(featuredError: TestError.boom)

        interactor.loadInitial(request: Home.Load.Request())
        await waitForLoadedRows(presenter, count: 4)

        XCTAssertTrue(presenter.lastResponse?.featured.isEmpty ?? false)
        XCTAssertEqual(presenter.lastResponse?.rows.count, 4)
        XCTAssertTrue(spy.contains("home_load_failure"))
    }

    /// API/network fully down: banner AND all rows fail → present a friendly,
    /// retryable error instead of leaving the user on empty rows.
    func testTotalFailurePresentsError() async {
        let bus = AnalyticsManager(delivery: .synchronous)
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        let interactor = HomeInteractor(
            featuredService: MockFeaturedService(result: [], error: TestError.boom),
            genreService: MockGenreService(pages: [], error: TestError.boom),
            analytics: bus
        )
        let presenter = SpyHomePresenter()
        interactor.presenter = presenter

        let sawError = expectation(description: "error presented")
        sawError.assertForOverFulfill = false
        presenter.onError = { _ in sawError.fulfill() }

        interactor.loadInitial(request: Home.Load.Request())
        await fulfillment(of: [sawError], timeout: 2)

        XCTAssertNotNil(presenter.lastError)
        XCTAssertTrue(spy.contains("home_load_failure"))
    }
}
