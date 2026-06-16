//
//  DetailModels.swift
//  AnimeApp
//
//  VIP scene models for the Anime Detail module.
//

import Foundation

enum Detail {

    enum Load {
        struct Request {}
        struct Response {
            let anime: Anime
            let characters: [CharacterEntry]
        }
    }

    /// Dumb, render-ready snapshot of the detail screen.
    struct ViewModel {
        let title: String
        let score: String
        let meta: String
        let genres: String
        let synopsis: String
        let heroImageURL: URL?
        let characters: [Character]
    }

    struct Character: CharacterDisplaying, Hashable {
        let name: String
        let imageURL: URL?

        var characterName: String { name }
        var characterImageURL: URL? { imageURL }
    }
}
