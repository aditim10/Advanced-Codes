//
//  CharacterService.swift
//  AnimeApp
//
//  Service for a single character's full profile (bio, nicknames, favorites,
//  voice actors), used by the Character Detail screen.
//

import Foundation
import ConcurrentAPI

// MARK: - CharacterServicing

protocol CharacterServicing: Sendable {
    /// Fetches a character's full profile from `characters/{id}/full`.
    func characterFull(id: Int) async throws -> CharacterFull
}

// MARK: - CharacterService

struct CharacterService: CharacterServicing {

    private let client: APIClient

    init(client: APIClient = AnimeAPI.client) {
        self.client = client
    }

    func characterFull(id: Int) async throws -> CharacterFull {
        try await client.sendWithRetry(CharacterFullRequest(id: id)).data
    }
}
