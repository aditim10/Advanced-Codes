//
//  SeeAllPresenterTests.swift
//  AnimeAppTests
//
//  Verifies the "See all" Presenter's UI logic: domain anime → diffable-ready
//  grid items, plus status mapping (loading/loaded/error).
//

import XCTest
@testable import AnimeApp

@MainActor
final class SpySeeAllDisplay: SeeAllDisplayLogic {
    private(set) var lastViewModel: SeeAll.ViewModel?
    func display(_ viewModel: SeeAll.ViewModel) { lastViewModel = viewModel }
}

@MainActor
final class SeeAllPresenterTests: XCTestCase {

    private func makePresenter() -> (SeeAllPresenter, SpySeeAllDisplay) {
        let presenter = SeeAllPresenter()
        let display = SpySeeAllDisplay()
        presenter.viewController = display
        return (presenter, display)
    }

    func testLoadedMappingFromFixture() {
        let (presenter, display) = makePresenter()
        let items = Fixture.animeList("anime_by_genre")   // mock JSON response

        presenter.present(response: SeeAll.Response(status: .loaded, items: items))

        XCTAssertEqual(display.lastViewModel?.status, .loaded)
        XCTAssertEqual(display.lastViewModel?.items.count, 2)

        let demon = display.lastViewModel?.items.first { $0.id == 38000 }
        XCTAssertEqual(demon?.title, "Demon Slayer")
        XCTAssertEqual(demon?.meta, "2019  ·  26 eps")
        XCTAssertEqual(demon?.score, "8.4")
    }

    func testStatusMappingCoversLoadingAndError() {
        let (presenter, display) = makePresenter()

        presenter.present(response: SeeAll.Response(status: .loading, items: []))
        XCTAssertEqual(display.lastViewModel?.status, .loading)

        presenter.present(response: SeeAll.Response(status: .error("boom"), items: []))
        XCTAssertEqual(display.lastViewModel?.status, .error("boom"))
    }
}
