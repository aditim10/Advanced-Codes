//
//  TestSupport.swift
//  AnimeAppTests
//
//  Shared helpers for the unit tests: sample model factories, mock service
//  implementations of the `*Servicing` protocols, and a spy analytics provider.
//  Because every service and view model depends on a *protocol* (not a concrete
//  network type), the tests never touch the real network.
//

import Foundation
import AnalyticsKit
@testable import AnimeApp

// MARK: - Sample data

enum Sample {

    /// Builds a minimal but valid `Anime` for tests.
    static func anime(id: Int, title: String = "Title") -> Anime {
        Anime(
            malID: id,
            title: title,
            titleEnglish: nil,
            synopsis: "Synopsis \(id)",
            score: 8.5,
            episodes: 12,
            status: "Finished",
            year: 2020,
            images: AnimeImages(
                jpg: AnimeImages.ImageURLs(
                    imageURL: "https://example.com/\(id).jpg",
                    smallImageURL: nil,
                    largeImageURL: "https://example.com/\(id)_l.jpg"
                )
            ),
            genres: [Genre(malID: 1, name: "Action", count: nil)],
            trailer: nil
        )
    }

    /// A list of `count` sample anime with ids starting at `startID`.
    static func animeList(count: Int, startID: Int = 1) -> [Anime] {
        (0..<count).map { anime(id: startID + $0, title: "Anime \(startID + $0)") }
    }

    static func character(id: Int) -> CharacterEntry {
        CharacterEntry(
            character: AnimeCharacter(
                malID: id,
                name: "Character \(id)",
                images: CharacterImages(
                    jpg: CharacterImages.CharacterImageURLs(imageURL: nil)
                )
            ),
            role: "Main"
        )
    }
}

// MARK: - Spy analytics provider

/// Records every event it receives so tests can assert what was published.
final class SpyAnalyticsProvider: AnalyticsProvider {
    let name = "Spy"
    private(set) var events: [AnalyticsEvent] = []

    func record(_ event: AnalyticsEvent) { events.append(event) }

    /// All recorded event names, in order.
    var names: [String] { events.map(\.name) }

    func contains(_ eventName: String) -> Bool { names.contains(eventName) }
}

// MARK: - Mock services

/// Mock `FeaturedAnimeServicing`. Returns `result` or throws `error`.
struct MockFeaturedService: FeaturedAnimeServicing {
    var result: [Anime] = []
    var error: Error?

    func topAnime(limit: Int) async throws -> [Anime] {
        if let error { throw error }
        return result
    }
}

/// Mock `GenreAnimeServicing` that returns pre-canned pages keyed by request
/// order, so pagination can be exercised deterministically.
final class MockGenreService: GenreAnimeServicing, @unchecked Sendable {
    var pages: [AnimePage]
    var error: Error?
    private(set) var requestedPages: [Int] = []

    init(pages: [AnimePage] = [], error: Error? = nil) {
        self.pages = pages
        self.error = error
    }

    func anime(genreID: Int, page: Int, limit: Int) async throws -> AnimePage {
        if let error { throw error }
        requestedPages.append(page)
        // Map page (1-based) onto the pre-canned pages, clamping at the end.
        let index = min(page - 1, pages.count - 1)
        return pages.indices.contains(index) ? pages[index] : .empty
    }
}

/// Mock `AnimeSearchServicing`.
final class MockSearchService: AnimeSearchServicing, @unchecked Sendable {
    var pages: [AnimePage]
    var error: Error?
    private(set) var queries: [String] = []

    init(pages: [AnimePage] = [], error: Error? = nil) {
        self.pages = pages
        self.error = error
    }

    func search(query: String, page: Int, limit: Int) async throws -> AnimePage {
        queries.append(query)
        if let error { throw error }
        let index = min(page - 1, pages.count - 1)
        return pages.indices.contains(index) ? pages[index] : .empty
    }
}

/// Mock `AnimeDetailServicing`.
struct MockDetailService: AnimeDetailServicing {
    var anime: Anime
    var characters: [CharacterEntry] = []
    var error: Error?

    func detail(id: Int) async throws -> Anime {
        if let error { throw error }
        return anime
    }

    func characters(animeID: Int) async throws -> [CharacterEntry] {
        if let error { throw error }
        return characters
    }

    func detailWithCharacters(id: Int) async throws -> (anime: Anime, characters: [CharacterEntry]) {
        if let error { throw error }
        return (anime, characters)
    }
}

// MARK: - JSON fixtures (mock API responses)

/// Anchor class used to locate the unit-test bundle that the `.json` fixtures
/// are copied into. `Bundle(for:)` needs a type that lives in that bundle.
private final class FixtureBundleToken {}

/// Loads and decodes the bundled mock-response JSON files in
/// `AnimeAppTests/Fixtures/`. This is how the tests exercise the real decoding
/// path (`JikanListResponse`/`JikanSingleResponse` → domain models) **without
/// ever calling the network** — the JSON file stands in for the API response.
enum Fixture {

    /// Mirrors the app's `APIClient` decoder: a default `JSONDecoder` paired with
    /// the models' explicit snake_case `CodingKeys`.
    static let decoder = JSONDecoder()

    /// Raw bytes of `<name>.json` from the test bundle.
    static func data(_ name: String) -> Data {
        let bundle = Bundle(for: FixtureBundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            fatalError("Missing fixture '\(name).json' — is it added to the test target's resources?")
        }
        // swiftlint:disable:next force_try
        return try! Data(contentsOf: url)
    }

    /// Decodes `<name>.json` into an arbitrary `Decodable` (e.g. a Jikan envelope).
    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try decoder.decode(T.self, from: data(name))
    }

    /// Convenience: the `[Anime]` inside a Jikan *list* fixture.
    static func animeList(_ name: String) -> [Anime] {
        (try? decode(JikanListResponse<Anime>.self, from: name).data) ?? []
    }

    /// Convenience: the single `Anime` inside a Jikan *single-resource* fixture.
    static func anime(_ name: String) -> Anime {
        try! decode(JikanSingleResponse<Anime>.self, from: name).data
    }

    /// Convenience: the `[CharacterEntry]` inside a Jikan list fixture.
    static func characters(_ name: String) -> [CharacterEntry] {
        (try? decode(JikanListResponse<CharacterEntry>.self, from: name).data) ?? []
    }
}

// MARK: - Async test helpers

enum TestError: Error { case boom }
