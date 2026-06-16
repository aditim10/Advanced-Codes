//
//  AnimeSearchService.swift
//  AnimeApp
//
//  Service for full-text anime search. Paginated to support load-more in the
//  search results list.
//

import Foundation
import ConcurrentAPI

// MARK: - AnimeSearchServicing

protocol AnimeSearchServicing: Sendable {
    /// One page of search results for `query`. Empty query returns an empty page.
    func search(query: String, page: Int, limit: Int) async throws -> AnimePage
}

// MARK: - AnimeSearchService

struct AnimeSearchService: AnimeSearchServicing {

    private let client: APIClient

    init(client: APIClient = AnimeAPI.client) {
        self.client = client
    }

    func search(
        query: String,
        page: Int = 1,
        limit: Int = APIConstants.gridPageSize
    ) async throws -> AnimePage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let response = try await client.sendWithRetry(
            SearchAnimeRequest(query: trimmed, page: page, limit: limit)
        )
        return AnimePage(
            items: response.data,
            currentPage: response.pagination?.currentPage ?? page,
            hasNextPage: response.pagination?.hasNextPage ?? false
        )
    }
}
