//
//  CharacterDetailModels.swift
//  AnimeApp
//
//  VIP scene models for the Character Detail module.
//

import Foundation

enum CharacterDetail {

    enum Load {
        struct Request {}
        struct Response { let character: CharacterFull }
    }

    /// Dumb, render-ready snapshot of the character screen.
    struct ViewModel {
        let name: String
        /// Kanji / original-language name, if any.
        let kanji: String?
        /// Pre-formatted favourites string (e.g. "12,345 favorites"), or `nil`.
        let favorites: String?
        /// Comma-joined nicknames, or `nil` if the character has none.
        let nicknames: String?
        /// Biography text, or `nil` if Jikan has none.
        let about: String?
        let imageURL: URL?
        let voiceActors: [VoiceActor]
    }

    struct VoiceActor: Hashable {
        let name: String
        let language: String
        let imageURL: URL?
    }
}
