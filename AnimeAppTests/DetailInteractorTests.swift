//
//  DetailInteractorTests.swift
//  AnimeAppTests
//
//  Covers the Detail VIP flow: seed render, concurrent detail+characters fetch,
//  and the formatted snapshot the Presenter produces.
//

import XCTest
@testable import AnimeApp

@MainActor
final class SpyDetailPresenter: DetailPresentationLogic {
    private(set) var loadingStates: [Bool] = []
    private(set) var responses: [Detail.Load.Response] = []
    private(set) var errors: [String] = []
    var onResponse: ((Detail.Load.Response) -> Void)?

    func presentLoading(_ isLoading: Bool) { loadingStates.append(isLoading) }
    func presentDetail(response: Detail.Load.Response) {
        responses.append(response)
        onResponse?(response)
    }
    func presentError(_ message: String) { errors.append(message) }
}

@MainActor
final class DetailInteractorTests: XCTestCase {

    func testLoadRendersSeedThenFullDetailAndCharacters() async {
        let seed = Sample.anime(id: 1, title: "Seed")
        let full = Sample.anime(id: 1, title: "Full Detail")
        let interactor = DetailInteractor(service: MockDetailService(
            anime: full,
            characters: [Sample.character(id: 10), Sample.character(id: 11)]))
        let presenter = SpyDetailPresenter()
        interactor.presenter = presenter

        let exp = expectation(description: "full loaded")
        exp.assertForOverFulfill = false
        presenter.onResponse = { response in
            if response.characters.count == 2 { exp.fulfill() }
        }

        interactor.setInitialAnime(seed)
        interactor.load(request: Detail.Load.Request())

        // First response is the synchronous seed render.
        XCTAssertEqual(presenter.responses.first?.anime.title, "Seed")
        XCTAssertEqual(presenter.responses.first?.characters.count, 0)

        await fulfillment(of: [exp], timeout: 2)
        XCTAssertEqual(presenter.responses.last?.anime.title, "Full Detail")
        XCTAssertEqual(presenter.responses.last?.characters.count, 2)
    }

    func testLoadFailureReportsError() async {
        let seed = Sample.anime(id: 1)
        let interactor = DetailInteractor(service: MockDetailService(
            anime: seed, characters: [], error: TestError.boom))
        let presenter = SpyDetailPresenter()
        interactor.presenter = presenter

        interactor.setInitialAnime(seed)
        interactor.load(request: Detail.Load.Request())

        // Poll briefly for the async failure.
        for _ in 0..<20 where presenter.errors.isEmpty {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertFalse(presenter.errors.isEmpty)
    }

    func testPresenterFormatsDisplayStrings() {
        let presenter = DetailPresenter()
        final class CaptureView: DetailDisplayLogic {
            var vm: Detail.ViewModel?
            func displayLoading(_ isLoading: Bool) {}
            func displayDetail(_ viewModel: Detail.ViewModel) { vm = viewModel }
            func displayError(_ message: String) {}
        }
        let view = CaptureView()
        presenter.viewController = view

        presenter.presentDetail(response: Detail.Load.Response(
            anime: Sample.anime(id: 1, title: "X"), characters: []))

        XCTAssertEqual(view.vm?.score, "⭐ 8.5")
        XCTAssertEqual(view.vm?.meta.contains("2020"), true)
        XCTAssertEqual(view.vm?.title, "X")
    }
}
