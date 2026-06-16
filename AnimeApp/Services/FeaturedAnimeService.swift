//
//  FeaturedAnimeService.swift
//  AnimeApp
//
//  Service for the featured/top anime used by the home banner carousel.
//

import Foundation
import ConcurrentAPI

// MARK: - FeaturedAnimeServicing

/// Abstraction so view models can be tested with a mock implementation.
protocol FeaturedAnimeServicing: Sendable {
    /// Highest-rated anime, newest scores first.
    func topAnime(limit: Int) async throws -> [Anime]
}

// MARK: - FeaturedAnimeService

struct FeaturedAnimeService: FeaturedAnimeServicing {

    private let client: APIClient

    init(client: APIClient = AnimeAPI.client) {
        self.client = client
    }

    func topAnime(limit: Int = APIConstants.bannerLimit) async throws -> [Anime] {
        try await client.sendWithRetry(TopAnimeRequest(limit: limit)).data
    }
}
