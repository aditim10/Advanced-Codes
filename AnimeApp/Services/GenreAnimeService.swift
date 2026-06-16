//
//  GenreAnimeService.swift
//  AnimeApp
//
//  Service for fetching score-sorted anime within a genre. Paginated so it backs
//  both the home carousels and the "See all" infinite-scroll grid.
//

import Foundation
import ConcurrentAPI

// MARK: - GenreAnimeServicing

protocol GenreAnimeServicing: Sendable {
    /// One page of anime for `genreID`, sorted by score descending.
    func anime(genreID: Int, page: Int, limit: Int) async throws -> AnimePage
}

// MARK: - GenreAnimeService

struct GenreAnimeService: GenreAnimeServicing {

    private let client: APIClient

    init(client: APIClient = AnimeAPI.client) {
        self.client = client
    }

    func anime(
        genreID: Int,
        page: Int = 1,
        limit: Int = APIConstants.rowPageSize
    ) async throws -> AnimePage {
        let response = try await client.sendWithRetry(
            AnimeByGenreRequest(genreID: genreID, page: page, limit: limit)
        )
        return AnimePage(
            items: response.data,
            currentPage: response.pagination?.currentPage ?? page,
            hasNextPage: response.pagination?.hasNextPage ?? false
        )
    }
}
