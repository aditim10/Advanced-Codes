//  APIConstants.swift
//
//  All networking-related constants live here as namespaced enums so call sites
//  read clearly (e.g. `APIConstants.baseURL`, `Endpoint.topAnime`) and there are
//  no stringly-typed literals scattered across services.
//

import Foundation

// MARK: - APIConstants

/// Top-level networking configuration values for the Jikan v4 API.
/// Jikan is keyless but rate-limited, hence the conservative page sizes.
enum APIConstants {

    /// Base URL for the Jikan v4 REST API (https://docs.api.jikan.moe).
    static let baseURL = URL(string: "https://api.jikan.moe/v4")!

    /// Per-request timeout, in seconds.
    static let timeout: TimeInterval = 20

    /// Default number of retries for transient failures (HTTP 429 / 5xx).
    static let maxRetries = 3

    /// Base back-off (seconds) between retries; multiplied by the attempt index.
    static let retryBackoff: TimeInterval = 0.6

    /// Maximum number of list requests fired at once during a screen's initial
    /// load. Jikan rate-limits bursts (≈3 req/s, 60/min), so the home feed loads
    /// its genre rows in small concurrent batches instead of all at once — this
    /// avoids the 429-storm that left rows empty/slow on launch.
    static let maxConcurrentLoads = 2

    // MARK: Page sizes

    /// Number of items shown in a home-screen carousel row.
    static let rowPageSize = 12

    /// Number of items fetched per page on the "See all" / search grids.
    static let gridPageSize = 24

    /// Number of hero items in the featured banner carousel.
    static let bannerLimit = 6
}

// MARK: - Endpoint

/// Path components appended to ``APIConstants/baseURL``. Centralising them keeps
/// request structs free of hardcoded path strings.
enum Endpoint {
    static let anime = "anime"
    static let topAnime = "top/anime"
    static let genres = "genres/anime"

    /// Detail for a single anime, e.g. `anime/1535`.
    static func anime(id: Int) -> String { "anime/\(id)" }

    /// Characters for a single anime, e.g. `anime/1535/characters`.
    static func characters(animeID: Int) -> String { "anime/\(animeID)/characters" }
}

// MARK: - QueryKey

/// Query-parameter names accepted by the Jikan API.
enum QueryKey {
    static let query = "q"
    static let genres = "genres"
    static let page = "page"
    static let limit = "limit"
    static let orderBy = "order_by"
    static let sort = "sort"
    static let sfw = "sfw"
}

// MARK: - QueryValue

/// Reusable query-parameter values.
enum QueryValue {
    static let orderByScore = "score"
    static let sortDesc = "desc"
    static let safeForWork = "true"
}
