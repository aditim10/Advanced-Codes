//
//  SeeAllPresenter.swift
//  AnimeApp
//
//  VIP Presenter for the "See all" grid: maps domain anime into a dumb,
//  diffable-ready snapshot.
//

import Foundation

@MainActor
protocol SeeAllPresentationLogic {
    func present(response: SeeAll.Response)
}

@MainActor
final class SeeAllPresenter: SeeAllPresentationLogic {

    weak var viewController: SeeAllDisplayLogic?

    func present(response: SeeAll.Response) {
        let items = response.items.map { anime in
            SeeAll.Item(
                id: anime.malID,
                title: anime.displayTitle,
                meta: [anime.yearText, anime.episodesText].joined(separator: "  ·  "),
                score: anime.scoreText,
                posterURL: anime.posterURL
            )
        }

        let status: SeeAll.ViewModel.Status
        switch response.status {
        case .loading:            status = .loading
        case .loaded:             status = .loaded
        case .error(let message): status = .error(message)
        }

        viewController?.display(SeeAll.ViewModel(status: status, items: items))
    }
}
