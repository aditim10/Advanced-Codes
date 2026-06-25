//
//  SearchPresenterTests.swift
//  AnimeAppTests
//
//  Verifies the Search Presenter's UI logic: domain results → diffable-ready
//  `Search.ViewModel` items, plus status mapping (idle/loading/results/empty).
//

import XCTest
@testable import AnimeApp

@MainActor
final class SpySearchDisplay: SearchDisplayLogic {
    private(set) var lastViewModel: Search.ViewModel?
    func display(_ viewModel: Search.ViewModel) { lastViewModel = viewModel }
}

@MainActor
final class SearchPresenterTests: XCTestCase {

    private func makePresenter() -> (SearchPresenter, SpySearchDisplay) {
        let presenter = SearchPresenter()
        let display = SpySearchDisplay()
        presenter.viewController = display
        return (presenter, display)
    }

    func testResultsMappingFromFixture() {
        let (presenter, display) = makePresenter()
        let items = Fixture.animeList("anime_by_genre")   // mock JSON response

        presenter.present(response: Search.Response(status: .results, items: items))

        XCTAssertEqual(display.lastViewModel?.status, .results)
        XCTAssertEqual(display.lastViewModel?.items.count, 2)

        let first = display.lastViewModel?.items.first
        XCTAssertEqual(first?.id, 16498)
        XCTAssertEqual(first?.title, "Attack on Titan")
        XCTAssertEqual(first?.meta, "2013  ·  25 eps")
        XCTAssertEqual(first?.score, "8.5")
        XCTAssertEqual(first?.posterURL?.absoluteString,
                       "https://cdn.myanimelist.net/images/anime/10/47347l.jpg")
    }

    func testStatusMappingCoversEveryCase() {
        let (presenter, display) = makePresenter()

        presenter.present(response: Search.Response(status: .idle, items: []))
        XCTAssertEqual(display.lastViewModel?.status, .idle)

        presenter.present(response: Search.Response(status: .loading, items: []))
        XCTAssertEqual(display.lastViewModel?.status, .loading)

        presenter.present(response: Search.Response(status: .empty, items: []))
        XCTAssertEqual(display.lastViewModel?.status, .empty)
        XCTAssertTrue(display.lastViewModel?.items.isEmpty ?? false)
    }
}
