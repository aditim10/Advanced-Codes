//  AppConstants.swift
//
//  Non-networking app-wide constants, grouped into one focused enum per concern.
//

import Foundation
import CoreGraphics

// MARK: - StorageKey

/// Keys used with `UserDefaults`. Keeping them here avoids typo'd string keys
/// silently reading/writing the wrong value.
enum StorageKey {
    /// The user's chosen ``ThemeMode`` (auto / light / dark).
    static let themeMode = "themeMode"
    /// Email of the logged-in user (also used as the "is logged in" flag).
    static let loggedInEmail = "loggedInEmail"
}

// MARK: - StoryboardID

/// Identifiers defined in `Main.storyboard`. Used for programmatic instantiation.
enum StoryboardID {
    static let main = "Main"
    static let homeNavigation = "HomeNavigationController"
    static let loginNavigation = "LoginNavigationController"
    static let animeDetail = "AnimeDetailViewController"
}

// MARK: - SegueID

/// Storyboard segue identifiers.
enum SegueID {
    static let showDetail = "showDetail"
    static let showDemo = "showDemo"
}

// MARK: - Layout

/// Shared sizing/spacing constants for programmatic layout.
enum Layout {
    static let bannerHeight: CGFloat = 400
    static let sectionRowHeight: CGFloat = 250
    static let cardSize = CGSize(width: 115, height: 175)
    static let cornerRadius: CGFloat = 14
    static let horizontalInset: CGFloat = 16

    /// How many rows from the bottom of a list triggers the next page fetch
    /// (infinite scroll). e.g. 3 == start loading when the 3rd-last row appears.
    static let paginationPrefetchDistance = 3
}
