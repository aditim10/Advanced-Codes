//
//  HomePresenterTests.swift
//  AnimeAppTests
//
//  Verifies the Home **Presenter's UI logic** — how it turns the Interactor's
//  raw domain `Response` into the dumb, render-ready `Home.ViewModel` snapshot
//  (banner/card formatting, meta strings, score text, loading flags). The
//  domain data comes from a bundled mock JSON fixture, so no network is hit.
//

import XCTest
@testable import AnimeApp

// MARK: - Spy display logic (the View)

@MainActor
final class SpyHomeDisplay: HomeDisplayLogic {
    private(set) var didDisplayLoading = false
    private(set) var lastViewModel: Home.ViewModel?
    private(set) var lastError: String?

    func displayLoading() { didDisplayLoading = true }
    func displaySnapshot(_ viewModel: Home.ViewModel) { lastViewModel = viewModel }
    func displayError(_ message: String) { lastError = message }
}

@MainActor
final class HomePresenterTests: XCTestCase {

    private func makePresenter() -> (HomePresenter, SpyHomeDisplay) {
        let presenter = HomePresenter()
        let display = SpyHomeDisplay()
        presenter.viewController = display
        return (presenter, display)
    }

    // MARK: presentLoading

    func testPresentLoadingForwardsToView() {
        let (presenter, display) = makePresenter()
        presenter.presentLoading()
        XCTAssertTrue(display.didDisplayLoading)
    }

    // MARK: presentSnapshot — banner formatting

    func testBannerFormattingFromFixture() {
        let (presenter, display) = makePresenter()
        let featured = Fixture.animeList("top_anime")   // mock JSON response

        presenter.presentSnapshot(response: Home.Load.Response(featured: featured, rows: []))

        let banners = display.lastViewModel?.banners
        XCTAssertEqual(banners?.count, 3)

        // Frieren — English title preferred, meta = "year  ·  eps", score "9.3".
        let frieren = banners?.first { $0.id == 52991 }
        XCTAssertEqual(frieren?.title, "Frieren: Beyond Journey's End")
        XCTAssertEqual(frieren?.meta, "2023  ·  28 eps")
        XCTAssertEqual(frieren?.score, "9.3")
        XCTAssertEqual(frieren?.posterURL?.absoluteString,
                       "https://cdn.myanimelist.net/images/anime/1015/138006l.jpg")
    }

    func testBannerHandlesMissingFields() {
        let (presenter, display) = makePresenter()
        let featured = Fixture.animeList("top_anime")

        presenter.presentSnapshot(response: Home.Load.Response(featured: featured, rows: []))

        // The third entry has null english title/score/year/episodes.
        let sparse = display.lastViewModel?.banners.first { $0.id == 9999 }
        XCTAssertEqual(sparse?.title, "Ongoing Title With Missing Fields") // falls back to romaji title
        XCTAssertEqual(sparse?.meta, "Unknown  ·  Ongoing")
        XCTAssertEqual(sparse?.score, "N/A")
    }

    // MARK: presentSnapshot — row + card mapping

    func testRowAndCardMappingPreservesIdentityAndLoadingFlag() {
        let (presenter, display) = makePresenter()
        let cards = Fixture.animeList("anime_by_genre")
        let loadedRow = AnimeSection(title: "⚔️  Action Hits", genreID: 1, anime: cards, isLoading: false)
        let shimmerRow = AnimeSection(title: "🔥 Top Adventure", genreID: 2, anime: [], isLoading: true)

        presenter.presentSnapshot(
            response: Home.Load.Response(featured: [], rows: [loadedRow, shimmerRow]))

        let rows = display.lastViewModel?.rows
        XCTAssertEqual(rows?.count, 2)

        XCTAssertEqual(rows?[0].id, 1)              // genreID is the diffable identity
        XCTAssertEqual(rows?[0].title, "⚔️  Action Hits")
        XCTAssertFalse(rows?[0].isLoading ?? true)
        XCTAssertEqual(rows?[0].cards.count, 2)
        XCTAssertEqual(rows?[0].cards.first?.title, "Attack on Titan")
        XCTAssertEqual(rows?[0].cards.first?.meta, "2013  ·  25 eps")
        XCTAssertEqual(rows?[0].cards.first?.score, "8.5")

        XCTAssertEqual(rows?[1].id, 2)
        XCTAssertTrue(rows?[1].isLoading ?? false)
        XCTAssertTrue(rows?[1].cards.isEmpty ?? false)
    }

    // MARK: presentError

    func testPresentErrorForwardsMessage() {
        let (presenter, display) = makePresenter()
        presenter.presentError("Network down")
        XCTAssertEqual(display.lastError, "Network down")
    }
}
