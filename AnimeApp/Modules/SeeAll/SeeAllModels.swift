//
//  SeeAllModels.swift
//  AnimeApp
//
//  VIP scene models for the "See all" genre grid.
//

import Foundation

enum SeeAll {

    enum Load { struct Request {} }
    enum Paginate { struct Request { let currentIndex: Int } }

    struct Response {
        enum Status { case loading, loaded, error(String) }
        let status: Status
        let items: [Anime]
    }

    struct ViewModel {
        enum Status: Equatable { case loading, loaded, error(String) }
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
