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
        /// YouTube video id for the trailer, or `nil` if this title has none.
        let trailerYouTubeID: String?
    }

    struct Character: CharacterDisplaying, Hashable {
        /// MyAnimeList character id — used to open the character's detail screen.
        let id: Int
        let name: String
        let imageURL: URL?

        var characterName: String { name }
        var characterImageURL: URL? { imageURL }
    }
}
