//
//  SearchModels.swift
//  AnimeApp
//
//  VIP scene models for the Search module.
//

import Foundation

enum Search {

    enum Query { struct Request { let text: String } }
    enum Paginate { struct Request { let currentIndex: Int } }

    /// Raw outcome the Interactor hands the Presenter.
    struct Response {
        enum Status { case idle, loading, results, empty }
        let status: Status
        let items: [Anime]
    }

    /// Dumb, render-ready snapshot for the View.
    struct ViewModel {
        enum Status { case idle, loading, results, empty }
        let status: Status
        let items: [Item]
    }

    struct Item: Hashable, AnimeCardDisplaying {
        let id: Int
        let title: String
        let meta: String
        let score: String
        let posterURL: URL?

        var cardID: Int { id }
        var cardTitle: String { title }
        var cardMeta: String { meta }
        var cardScore: String { score }
        var cardPosterURL: URL? { posterURL }
    }
}
