//
//  JikanResponses.swift
//  AnimeApp
//
//  "Raw" decodable envelopes returned by the Jikan API. These map 1:1 to the
//  JSON wire format and are kept separate from the domain models (in Models/)
//  so the networking shape and the app's view models stay decoupled.
//

import Foundation

// MARK: - List envelope

/// Jikan wraps list endpoints in `{ "data": [...], "pagination": {...} }`.
struct JikanListResponse<Element: Codable & Sendable>: Codable, Sendable {
    let data: [Element]
    let pagination: Pagination?
}

// MARK: - Single envelope

/// Jikan wraps single-resource endpoints in `{ "data": {...} }`.
struct JikanSingleResponse<Element: Codable & Sendable>: Codable, Sendable {
    let data: Element
}

// MARK: - Pagination

/// Pagination metadata included with list responses; drives infinite scroll.
struct Pagination: Codable, Sendable {
    let lastVisiblePage: Int
    let hasNextPage: Bool
    let currentPage: Int
    let items: PaginationItems?

    enum CodingKeys: String, CodingKey {
        case lastVisiblePage = "last_visible_page"
        case hasNextPage = "has_next_page"
        case currentPage = "current_page"
        case items
    }
}

struct PaginationItems: Codable, Sendable {
    let count: Int
    let total: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case count
        case total
        case perPage = "per_page"
    }
}
