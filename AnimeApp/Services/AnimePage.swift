//
//  AnimePage.swift
//  AnimeApp
//
//  A lightweight, paginated slice of anime returned by the paginated services
//  (genre + search). Flattens Jikan's pagination envelope into just the bits the
//  view models need to drive infinite scroll.
//

import Foundation

/// One page of anime results plus enough metadata to fetch the next page.
struct AnimePage: Sendable {
    let items: [Anime]
    let currentPage: Int
    let hasNextPage: Bool

    static let empty = AnimePage(items: [], currentPage: 1, hasNextPage: false)
}
