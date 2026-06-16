//
//  SearchPresenter.swift
//  AnimeApp
//
//  VIP Presenter for Search: maps domain results into a dumb, diffable-ready
//  snapshot.
//

import Foundation

@MainActor
protocol SearchPresentationLogic {
    func present(response: Search.Response)
}

@MainActor
final class SearchPresenter: SearchPresentationLogic {

    weak var viewController: SearchDisplayLogic?

    func present(response: Search.Response) {
        let items = response.items.map { anime in
            Search.Item(
                id: anime.malID,
                title: anime.displayTitle,
                meta: [anime.yearText, anime.episodesText].joined(separator: "  ·  "),
                score: anime.scoreText,
                posterURL: anime.posterURL
            )
        }

        let status: Search.ViewModel.Status
        switch response.status {
        case .idle:    status = .idle
        case .loading: status = .loading
        case .results: status = .results
        case .empty:   status = .empty
        }

        viewController?.display(Search.ViewModel(status: status, items: items))
    }
}
