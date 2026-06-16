//
//  DetailPresenterTests.swift
//  AnimeAppTests
//
//  Verifies the Detail Presenter's UI logic: domain anime + cast → render-ready
//  `Detail.ViewModel` (score prefix, joined meta line, synopsis fallback, cast
//  mapping). Domain data is decoded from bundled mock JSON.
//

import XCTest
@testable import AnimeApp

@MainActor
final class SpyDetailDisplay: DetailDisplayLogic {
    private(set) var loadingStates: [Bool] = []
    private(set) var lastViewModel: Detail.ViewModel?
    private(set) var lastError: String?

    func displayLoading(_ isLoading: Bool) { loadingStates.append(isLoading) }
    func displayDetail(_ viewModel: Detail.ViewModel) { lastViewModel = viewModel }
    func displayError(_ message: String) { lastError = message }
}

@MainActor
final class DetailPresenterTests: XCTestCase {

    private func makePresenter() -> (DetailPresenter, SpyDetailDisplay) {
        let presenter = DetailPresenter()
        let display = SpyDetailDisplay()
        presenter.viewController = display
        return (presenter, display)
    }

    func testPresentLoadingForwardsFlag() {
        let (presenter, display) = makePresenter()
        presenter.presentLoading(true)
        presenter.presentLoading(false)
        XCTAssertEqual(display.loadingStates, [true, false])
    }

    func testPresentDetailFormatsFromFixture() {
        let (presenter, display) = makePresenter()
        let anime = Fixture.anime("anime_detail")            // single mock JSON response
        let cast  = Fixture.characters("anime_characters")   // list mock JSON response

        presenter.presentDetail(response: Detail.Load.Response(anime: anime, characters: cast))

        let vm = display.lastViewModel
        XCTAssertEqual(vm?.title, "Death Note")
        XCTAssertEqual(vm?.score, "⭐ 8.6")
        XCTAssertEqual(vm?.meta, "2006  ·  37 eps  ·  Finished Airing")
        XCTAssertEqual(vm?.genres, "Supernatural · Suspense")
        XCTAssertEqual(vm?.heroImageURL?.absoluteString,
                       "https://cdn.myanimelist.net/images/anime/9/9453l.jpg")

        // Cast mapping preserves order + nil image URLs.
        XCTAssertEqual(vm?.characters.count, 3)
        XCTAssertEqual(vm?.characters.first?.name, "Lawliet, L")
        XCTAssertNotNil(vm?.characters.first?.imageURL)
        XCTAssertNil(vm?.characters.last?.imageURL)   // Misa has a null image_url
    }

    func testPresentDetailUsesSynopsisFallbackWhenMissing() {
        let (presenter, display) = makePresenter()
        // Build an anime with no synopsis directly (Sample has one, so override).
        let base = Fixture.anime("anime_detail")
        let noSynopsis = Anime(
            malID: base.malID, title: base.title, titleEnglish: base.titleEnglish,
            synopsis: nil, score: base.score, episodes: base.episodes, status: base.status,
            year: base.year, images: base.images, genres: base.genres)

        presenter.presentDetail(response: Detail.Load.Response(anime: noSynopsis, characters: []))

        XCTAssertEqual(display.lastViewModel?.synopsis, AppStrings.Detail.noSynopsis)
        XCTAssertTrue(display.lastViewModel?.characters.isEmpty ?? false)
    }

    func testPresentErrorForwardsMessage() {
        let (presenter, display) = makePresenter()
        presenter.presentError("Could not load")
        XCTAssertEqual(display.lastError, "Could not load")
    }
}
