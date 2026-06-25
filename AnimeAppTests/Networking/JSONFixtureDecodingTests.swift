//
//  JSONFixtureDecodingTests.swift
//  AnimeAppTests
//
//  Proves the *mock JSON response* files decode correctly through the exact
//  Jikan envelopes + domain models the real API uses — snake_case key mapping,
//  optional/null handling, and pagination. No network is involved: the bundled
//  `.json` files stand in for the API responses.
//

import XCTest
@testable import AnimeApp

final class JSONFixtureDecodingTests: XCTestCase {

    // MARK: List envelope (top/anime, anime?genres=…, search)

    func testDecodeTopAnimeListResponse() throws {
        let response = try Fixture.decode(JikanListResponse<Anime>.self, from: "top_anime")

        XCTAssertEqual(response.data.count, 3)
        XCTAssertEqual(response.pagination?.hasNextPage, true)        // has_next_page
        XCTAssertEqual(response.pagination?.currentPage, 1)           // current_page
        XCTAssertEqual(response.pagination?.items?.perPage, 25)       // per_page

        let fma = try XCTUnwrap(response.data.first)
        XCTAssertEqual(fma.malID, 5114)                               // mal_id
        XCTAssertEqual(fma.score, 9.1)
        XCTAssertEqual(fma.episodes, 64)
        XCTAssertEqual(fma.genres.count, 3)
        XCTAssertEqual(fma.images.jpg.largeImageURL,                  // large_image_url
                       "https://cdn.myanimelist.net/images/anime/1223/96541l.jpg")
    }

    func testDecodeHandlesNullableFields() throws {
        let response = try Fixture.decode(JikanListResponse<Anime>.self, from: "top_anime")
        let sparse = try XCTUnwrap(response.data.first { $0.malID == 9999 })

        XCTAssertNil(sparse.titleEnglish)
        XCTAssertNil(sparse.score)
        XCTAssertNil(sparse.episodes)
        XCTAssertNil(sparse.year)
        XCTAssertNil(sparse.images.jpg.largeImageURL)
        XCTAssertTrue(sparse.genres.isEmpty)

        // Display helpers degrade gracefully on the missing values.
        XCTAssertEqual(sparse.displayTitle, "Ongoing Title With Missing Fields")
        XCTAssertEqual(sparse.scoreText, "N/A")
        XCTAssertEqual(sparse.episodesText, "Ongoing")
        XCTAssertEqual(sparse.yearText, "Unknown")
    }

    // MARK: Single envelope (anime/{id})

    func testDecodeAnimeDetailSingleResponse() throws {
        let response = try Fixture.decode(JikanSingleResponse<Anime>.self, from: "anime_detail")
        let anime = response.data

        XCTAssertEqual(anime.malID, 1535)
        XCTAssertEqual(anime.displayTitle, "Death Note")
        XCTAssertEqual(anime.score, 8.6)
        XCTAssertEqual(anime.genreNames, "Supernatural · Suspense")
    }

    // MARK: Characters list (anime/{id}/characters)

    func testDecodeCharactersResponse() throws {
        let response = try Fixture.decode(JikanListResponse<CharacterEntry>.self, from: "anime_characters")

        XCTAssertEqual(response.data.count, 3)
        let first = try XCTUnwrap(response.data.first)
        XCTAssertEqual(first.character.name, "Lawliet, L")
        XCTAssertEqual(first.role, "Main")
        XCTAssertNotNil(first.character.imageURL)

        let misa = try XCTUnwrap(response.data.first { $0.character.malID == 6212 })
        XCTAssertNil(misa.character.imageURL)                         // null image_url → nil URL
    }

    // MARK: Convenience accessors used across the presenter tests

    func testFixtureConvenienceAccessors() {
        XCTAssertEqual(Fixture.animeList("top_anime").count, 3)
        XCTAssertEqual(Fixture.animeList("anime_by_genre").count, 2)
        XCTAssertEqual(Fixture.anime("anime_detail").malID, 1535)
        XCTAssertEqual(Fixture.characters("anime_characters").count, 3)
    }
}
