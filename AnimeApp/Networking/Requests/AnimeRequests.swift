//
//  AnimeRequests.swift
//  AnimeApp
//
//  One `APIRequest` struct per Jikan endpoint. This is the "describe the call"
//  half of the networking layer — services (Services/) execute these through the
//  shared `APIClient` and translate the raw response into domain models.
//

import Foundation
import ConcurrentAPI

// MARK: - Top anime (featured banner)

/// `GET top/anime` — highest-rated anime, used for the featured carousel.
struct TopAnimeRequest: APIRequest {
    typealias Response = JikanListResponse<Anime>

    let limit: Int

    var path: String { Endpoint.topAnime }
    var queryItems: [URLQueryItem]? {
        [
            URLQueryItem(name: QueryKey.limit, value: "\(limit)"),
            URLQueryItem(name: QueryKey.sfw, value: QueryValue.safeForWork)
        ]
    }
}

// MARK: - Anime by genre (home rows + "See all")

/// `GET anime?genres=…` — score-sorted anime within a genre, paginated.
struct AnimeByGenreRequest: APIRequest {
    typealias Response = JikanListResponse<Anime>

    let genreID: Int
    let page: Int
    let limit: Int

    var path: String { Endpoint.anime }
    var queryItems: [URLQueryItem]? {
        [
            URLQueryItem(name: QueryKey.genres, value: "\(genreID)"),
            URLQueryItem(name: QueryKey.page, value: "\(page)"),
            URLQueryItem(name: QueryKey.limit, value: "\(limit)"),
            URLQueryItem(name: QueryKey.orderBy, value: QueryValue.orderByScore),
            URLQueryItem(name: QueryKey.sort, value: QueryValue.sortDesc),
            URLQueryItem(name: QueryKey.sfw, value: QueryValue.safeForWork)
        ]
    }
}

// MARK: - Search

/// `GET anime?q=…` — full-text title search, paginated.
struct SearchAnimeRequest: APIRequest {
    typealias Response = JikanListResponse<Anime>

    let query: String
    let page: Int
    let limit: Int

    var path: String { Endpoint.anime }
    var queryItems: [URLQueryItem]? {
        [
            URLQueryItem(name: QueryKey.query, value: query),
            URLQueryItem(name: QueryKey.page, value: "\(page)"),
            URLQueryItem(name: QueryKey.limit, value: "\(limit)"),
            URLQueryItem(name: QueryKey.orderBy, value: QueryValue.orderByScore),
            URLQueryItem(name: QueryKey.sort, value: QueryValue.sortDesc),
            URLQueryItem(name: QueryKey.sfw, value: QueryValue.safeForWork)
        ]
    }
}

// MARK: - Detail

/// `GET anime/{id}` — full detail for a single title.
struct AnimeDetailRequest: APIRequest {
    typealias Response = JikanSingleResponse<Anime>

    let id: Int
    var path: String { Endpoint.anime(id: id) }
}

// MARK: - Characters

/// `GET anime/{id}/characters` — the cast for a single title.
struct AnimeCharactersRequest: APIRequest {
    typealias Response = JikanListResponse<CharacterEntry>

    let animeID: Int
    var path: String { Endpoint.characters(animeID: animeID) }
}

// MARK: - Genres

/// `GET genres/anime` — the full list of selectable genres.
struct GenreListRequest: APIRequest {
    typealias Response = JikanListResponse<Genre>

    var path: String { Endpoint.genres }
}
