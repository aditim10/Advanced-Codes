//
//  AnimeDetailService.swift
//  AnimeApp
//
//  Service for a single anime's full detail and cast. Exposes a combined call
//  that fetches both concurrently.
//

import Foundation
import ConcurrentAPI

// MARK: - AnimeDetailServicing

protocol AnimeDetailServicing: Sendable {
    func detail(id: Int) async throws -> Anime
    func characters(animeID: Int) async throws -> [CharacterEntry]
    /// Fetches full detail and characters concurrently.
    func detailWithCharacters(id: Int) async throws -> (anime: Anime, characters: [CharacterEntry])
}

// MARK: - AnimeDetailService

struct AnimeDetailService: AnimeDetailServicing {

    private let client: APIClient

    init(client: APIClient = AnimeAPI.client) {
        self.client = client
    }

    func detail(id: Int) async throws -> Anime {
        try await client.sendWithRetry(AnimeDetailRequest(id: id)).data
    }

    func characters(animeID: Int) async throws -> [CharacterEntry] {
        try await client.sendWithRetry(AnimeCharactersRequest(animeID: animeID)).data
    }

    func detailWithCharacters(id: Int) async throws -> (anime: Anime, characters: [CharacterEntry]) {
        async let detailTask     = detail(id: id)
        async let charactersTask = characters(animeID: id)
        return try await (detailTask, charactersTask)
    }
}
