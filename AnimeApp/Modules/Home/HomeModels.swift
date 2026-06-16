//
//  HomeModels.swift
//  AnimeApp
//
//  VIP "scene models" for the Home module. Following Clean Swift, every use case
//  is namespaced under `Home` as a Request → Response → ViewModel triple:
//
//    • Request  — what the View asks the Interactor to do (no data, usually).
//    • Response — raw domain data the Interactor hands the Presenter.
//    • ViewModel — the *dumb snapshot* the Presenter hands the View: render-ready
//      values only (formatted strings, URLs, flags). It contains NO logic and no
//      domain types, which is exactly what makes the View trivial and the
//      snapshot safe to drive a diffable data source.
//

import Foundation

enum Home {

    // MARK: - Use cases (View ↔ Interactor ↔ Presenter)

    /// Initial load (and pull-to-refresh) of the banner + first genre rows.
    enum Load {
        struct Request {}
        struct Response {
            let featured: [Anime]
            let rows: [AnimeSection]
        }
    }

    /// Infinite-scroll: append the next batch of genre rows.
    enum Paginate {
        struct Request {}
        // Pagination re-emits a full `Load.Response`, so the View always renders
        // one authoritative snapshot rather than diffing deltas by hand.
    }

    /// A banner/card tap. Carries the tapped anime's id so the Interactor's data
    /// store can resolve the domain object for routing.
    enum Select {
        struct Request { let animeID: Int }
    }

    // MARK: - Dumb display snapshot (no logic — just render-ready values)

    /// The complete, render-ready snapshot of the Home screen.
    struct ViewModel {
        let banners: [Banner]
        let rows: [Row]
    }

    /// A single hero item in the featured carousel.
    struct Banner: Hashable, AnimeCardDisplaying {
        let id: Int
        let title: String
        let meta: String
        let score: String
        let posterURL: URL?

        var cardID: Int { id }
        var cardTitle: String { title }
        var cardMeta: String { meta }
        var cardScore: String { score }
        var cardPosterURL: URL? { posterURL }
    }

    /// One genre carousel row. `id` (the genre id) is its stable identity for the
    /// diffable data source; when `cards`/`isLoading` change the row re-renders.
    struct Row: Hashable {
        let id: Int
        let title: String
        let isLoading: Bool
        let cards: [Card]
    }

    /// A single poster card inside a row.
    struct Card: Hashable, AnimeCardDisplaying {
        let id: Int
        let title: String
        let meta: String
        let score: String
        let posterURL: URL?

        var cardID: Int { id }
        var cardTitle: String { title }
        var cardMeta: String { meta }
        var cardScore: String { score }
        var cardPosterURL: URL? { posterURL }
    }
}
