//
//  DetailPresenter.swift
//  AnimeApp
//
//  VIP Presenter for Anime Detail: formats the domain anime + cast into a dumb
//  render-ready snapshot.
//

import Foundation

@MainActor
protocol DetailPresentationLogic {
    func presentLoading(_ isLoading: Bool)
    func presentDetail(response: Detail.Load.Response)
    func presentError(_ message: String)
}

@MainActor
final class DetailPresenter: DetailPresentationLogic {

    weak var viewController: DetailDisplayLogic?

    func presentLoading(_ isLoading: Bool) {
        viewController?.displayLoading(isLoading)
    }

    func presentDetail(response: Detail.Load.Response) {
        let anime = response.anime
        let meta = [anime.yearText, anime.episodesText, anime.status ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")

        let viewModel = Detail.ViewModel(
            title: anime.displayTitle,
            score: "⭐ \(anime.scoreText)",
            meta: meta,
            genres: anime.genreNames,
            synopsis: anime.synopsis ?? AppStrings.Detail.noSynopsis,
            heroImageURL: anime.posterURL,
            characters: response.characters.map {
                Detail.Character(id: $0.character.malID,
                                 name: $0.character.name,
                                 imageURL: $0.character.imageURL)
            },
            trailerYouTubeID: anime.trailerYouTubeID
        )
        viewController?.displayDetail(viewModel)
    }

    func presentError(_ message: String) {
        viewController?.displayError(message)
    }
}
