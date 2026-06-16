//
//  DetailInteractor.swift
//  AnimeApp
//
//  VIP Interactor for Anime Detail: holds the seed anime, renders it instantly,
//  then fetches the full detail + cast concurrently and re-presents.
//

import Foundation

@MainActor
protocol DetailBusinessLogic {
    /// Seeds the screen with the anime the user tapped (set before `load`).
    func setInitialAnime(_ anime: Anime)
    func load(request: Detail.Load.Request)
}

@MainActor
final class DetailInteractor: DetailBusinessLogic {

    var presenter: DetailPresentationLogic?

    private let service: AnimeDetailServicing
    private var anime: Anime?
    private var task: Task<Void, Never>?

    init(service: AnimeDetailServicing = AnimeDetailService()) {
        self.service = service
    }

    func setInitialAnime(_ anime: Anime) {
        self.anime = anime
    }

    func load(request: Detail.Load.Request) {
        guard let anime else { return }
        // Show what we already know immediately (no spinner-only screen).
        presenter?.presentDetail(response: Detail.Load.Response(anime: anime, characters: []))
        task?.cancel()
        task = Task { await fetch(id: anime.malID) }
    }

    private func fetch(id: Int) async {
        presenter?.presentLoading(true)
        do {
            let result = try await service.detailWithCharacters(id: id)
            anime = result.anime
            presenter?.presentLoading(false)
            presenter?.presentDetail(response: Detail.Load.Response(
                anime: result.anime, characters: result.characters))
        } catch {
            presenter?.presentLoading(false)
            presenter?.presentError(error.localizedDescription)
        }
    }
}
