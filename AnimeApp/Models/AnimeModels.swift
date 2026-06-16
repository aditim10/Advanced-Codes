//  AnimeModels.swift
//
//  Domain models used throughout the UI. They are `Decodable` so the networking
//  layer can decode Jikan JSON straight into them, and `Sendable` so they can
//  cross actor/task boundaries safely. The raw response *envelopes* that wrap
//  these live separately in Networking/Raw/JikanResponses.swift.
//

import Foundation

// MARK: - Anime

/// A single anime title plus the presentation helpers the UI needs.
struct Anime: Codable, Sendable, Identifiable {

    /// `Identifiable` conformance maps to MyAnimeList's id.
    var id: Int { malID }

    let malID: Int
    let title: String
    let titleEnglish: String?
    let synopsis: String?
    let score: Double?
    let episodes: Int?
    let status: String?
    let year: Int?
    let images: AnimeImages
    let genres: [Genre]
    /// Optional trailer (YouTube) info from Jikan. Present on most popular titles.
    let trailer: AnimeTrailer?

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case title
        case titleEnglish = "title_english"
        case synopsis
        case score
        case episodes
        case status
        case year
        case images
        case genres
        case trailer
    }

    // MARK: Display helpers

    /// Prefers the English title, falling back to the romaji/original title.
    var displayTitle: String { titleEnglish ?? title }

    /// Best available poster URL (large preferred, then default).
    var posterURL: URL? {
        images.jpg.largeImageURL.flatMap(URL.init) ?? images.jpg.imageURL.flatMap(URL.init)
    }

    var scoreText: String { score.map { String(format: "%.1f", $0) } ?? "N/A" }
    var episodesText: String { episodes.map { "\($0) eps" } ?? "Ongoing" }
    var yearText: String { year.map { "\($0)" } ?? "Unknown" }
    var genreNames: String { genres.prefix(3).map(\.name).joined(separator: " · ") }

    /// The trailer's YouTube video id, if this title has one. Jikan often leaves
    /// `youtube_id` null while still providing the id inside `embed_url`, so we
    /// fall back to parsing that.
    var trailerYouTubeID: String? {
        if let id = trailer?.youtubeID, !id.isEmpty { return id }
        return trailer?.embeddedVideoID
    }
}

// MARK: - AnimeTrailer

/// Jikan's `trailer` object: a YouTube video id plus the watch/embed URLs. The
/// same data MyAnimeList uses to render its trailer player.
struct AnimeTrailer: Codable, Sendable {
    let youtubeID: String?
    let url: String?
    let embedURL: String?

    enum CodingKeys: String, CodingKey {
        case youtubeID = "youtube_id"
        case url
        case embedURL = "embed_url"
    }

    /// Pulls the video id out of `embed_url` (e.g.
    /// `https://www.youtube-nocookie.com/embed/Vt_3c8BgxV4?…` → `Vt_3c8BgxV4`).
    /// Used when Jikan leaves `youtube_id` null.
    var embeddedVideoID: String? {
        guard let embedURL, let components = URLComponents(string: embedURL) else { return nil }
        // The id is the last non-empty path segment after "/embed/".
        let id = components.path.split(separator: "/").last.map(String.init)
        guard let id, !id.isEmpty else { return nil }
        return id
    }
}

// MARK: - AnimeImages

struct AnimeImages: Codable, Sendable {
    let jpg: ImageURLs

    struct ImageURLs: Codable, Sendable {
        let imageURL: String?
        let smallImageURL: String?
        let largeImageURL: String?

        enum CodingKeys: String, CodingKey {
            case imageURL = "image_url"
            case smallImageURL = "small_image_url"
            case largeImageURL = "large_image_url"
        }
    }
}

// MARK: - Genre

struct Genre: Codable, Sendable {
    let malID: Int
    let name: String
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case name
        case count
    }
}

// MARK: - Character

/// A character credit on an anime (the character plus their role).
struct CharacterEntry: Codable, Sendable {
    let character: AnimeCharacter
    let role: String
}

/// A single anime character. Named `AnimeCharacter` (not `Character`) to avoid
/// shadowing Swift's built-in `Character` type.
struct AnimeCharacter: Codable, Sendable {
    let malID: Int
    let name: String
    let images: CharacterImages

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case name
        case images
    }

    var imageURL: URL? { images.jpg.imageURL.flatMap(URL.init) }
}

struct CharacterImages: Codable, Sendable {
    let jpg: CharacterImageURLs

    struct CharacterImageURLs: Codable, Sendable {
        let imageURL: String?
        enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
    }
}

// MARK: - CharacterFull

/// A character's full profile from `GET characters/{id}/full`: biography,
/// nicknames, favorites count, and the voice actors who portrayed them.
struct CharacterFull: Codable, Sendable {
    let malID: Int
    let name: String
    let nameKanji: String?
    let nicknames: [String]
    let favorites: Int
    let about: String?
    let images: CharacterImages
    let voices: [CharacterVoice]

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case name
        case nameKanji = "name_kanji"
        case nicknames
        case favorites
        case about
        case images
        case voices
    }

    var imageURL: URL? { images.jpg.imageURL.flatMap(URL.init) }
}

/// One voice-actor credit for a character (the actor plus the dub language).
struct CharacterVoice: Codable, Sendable {
    let language: String
    let person: VoicePerson
}

/// The person (voice actor) behind a ``CharacterVoice``. Shares the same image
/// shape as a character (`images.jpg.image_url`).
struct VoicePerson: Codable, Sendable {
    let malID: Int
    let name: String
    let images: CharacterImages

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case name
        case images
    }

    var imageURL: URL? { images.jpg.imageURL.flatMap(URL.init) }
}

// MARK: - AnimeSection

/// A single home-screen carousel row: a titled, genre-backed list of anime.
struct AnimeSection {
    let title: String
    let genreID: Int
    var anime: [Anime]
    var isLoading: Bool = false
}

// MARK: - AnimeGenre

/// MyAnimeList genre ids used by the home screen. Raw values are Jikan genre ids.
enum AnimeGenre: Int, CaseIterable {
    case action = 1
    case adventure = 2
    case comedy = 4
    case drama = 8
    case fantasy = 10
    case scifi = 24
    case sports = 30
    case supernatural = 37

    /// Human-readable, display-ready name.
    var displayName: String {
        switch self {
        case .action: return "Action"
        case .adventure: return "Adventure"
        case .comedy: return "Comedy"
        case .drama: return "Drama"
        case .fantasy: return "Fantasy"
        case .scifi: return "Sci-Fi"
        case .sports: return "Sports"
        case .supernatural: return "Supernatural"
        }
    }

    /// Title (with emoji) shown above the genre's carousel row on Home.
    var sectionTitle: String {
        switch self {
        case .action: return "⚔️  Action Hits"
        case .adventure: return "🔥 Top Adventure"
        case .comedy: return "😂 Comedy"
        case .drama: return "🎭 Drama"
        case .fantasy: return "✨ Fantasy Worlds"
        case .scifi: return "🚀 Sci-Fi"
        case .sports: return "🏆 Sports"
        case .supernatural: return "👻 Supernatural"
        }
    }
}
