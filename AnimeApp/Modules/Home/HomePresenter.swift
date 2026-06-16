//
//  HomePresenter.swift
//  AnimeApp
//
//  The VIP **Presenter** for Home. Its only job is formatting: it turns the
//  Interactor's raw domain `Response` into a dumb, render-ready `Home.ViewModel`
//  snapshot and hands it to the View. All display string formatting (meta lines,
//  score text, etc.) lives here — never in the Interactor and never in the View.
//

import Foundation

@MainActor
protocol HomePresentationLogic {
    func presentLoading()
    func presentSnapshot(response: Home.Load.Response)
    func presentError(_ message: String)
}

@MainActor
final class HomePresenter: HomePresentationLogic {

    weak var viewController: HomeDisplayLogic?

    func presentLoading() {
        viewController?.displayLoading()
    }

    func presentSnapshot(response: Home.Load.Response) {
        let banners = response.featured.map { anime in
            Home.Banner(
                id: anime.malID,
                title: anime.displayTitle,
                meta: meta(for: anime),
                score: anime.scoreText,
                posterURL: anime.posterURL
            )
        }

        let rows = response.rows.map { section in
            Home.Row(
                id: section.genreID,
                title: section.title,
                isLoading: section.isLoading,
                cards: section.anime.map { card(from: $0) }
            )
        }

        viewController?.displaySnapshot(Home.ViewModel(banners: banners, rows: rows))
    }

    func presentError(_ message: String) {
        viewController?.displayError(message)
    }

    // MARK: - Formatting helpers

    private func card(from anime: Anime) -> Home.Card {
        Home.Card(
            id: anime.malID,
            title: anime.displayTitle,
            meta: meta(for: anime),
            score: anime.scoreText,
            posterURL: anime.posterURL
        )
    }

    private func meta(for anime: Anime) -> String {
        [anime.yearText, anime.episodesText].joined(separator: "  ·  ")
    }
}
