//  AppConstants.swift
//
//  Non-networking app-wide constants, grouped into one focused enum per concern.
//

import UIKit

// MARK: - StorageKey

/// Keys used with `UserDefaults`. Keeping them here avoids typo'd string keys
/// silently reading/writing the wrong value.
enum StorageKey {
    /// The user's chosen ``ThemeMode`` (auto / light / dark).
    static let themeMode = "themeMode"
    /// Email of the logged-in user (also used as the "is logged in" flag).
    static let loggedInEmail = "loggedInEmail"
    /// Display name the user entered at sign-in.
    static let userName = "userName"
    /// Stable, anonymous identifier sent to analytics in place of PII.
    static let analyticsUserID = "analyticsUserID"
    /// The viewer's chosen ad tier (ad-free / ad-lite / ad-supported).
    static let adTier = "adTier"
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
}

// MARK: - Layout

/// Shared sizing/spacing for programmatic layout. Sizes are **adaptive**: they
/// derive from the current size class (compact = iPhone, regular = iPad/large
/// split views) and the available bounds, so the UI scales across every device
/// and reflows on rotation instead of using fixed iPhone-sized points.
enum Layout {
    static let cornerRadius: CGFloat = 14
    static let horizontalInset: CGFloat = 16

    /// How many rows from the bottom of a list triggers the next page fetch
    /// (infinite scroll). e.g. 3 == start loading when the 3rd-last row appears.
    static let paginationPrefetchDistance = 3

    /// `true` for iPad / regular-width contexts (wider, roomier layouts).
    static func isRegular(_ traits: UITraitCollection) -> Bool {
        traits.horizontalSizeClass == .regular
    }

    // MARK: Poster cards (Home carousels + See All grid)

    /// Poster image height ÷ width — preserves the original 140:115 proportion.
    static let posterImageRatio: CGFloat = 1.22
    /// Fixed vertical space beneath a poster for the score + 2-line title.
    static let posterTextAllowance: CGFloat = 44

    /// Width of one poster card in the horizontal Home rails. Cards grow a little
    /// on regular-width devices; wider screens then simply show more of them.
    static func posterCardWidth(for traits: UITraitCollection) -> CGFloat {
        isRegular(traits) ? 150 : 116
    }

    /// Full poster cell size (image + text) for the Home rails.
    static func posterCardSize(for traits: UITraitCollection) -> CGSize {
        let w = posterCardWidth(for: traits)
        return CGSize(width: w, height: (w * posterImageRatio).rounded() + posterTextAllowance)
    }

    /// Height of a Home section row: title strip + the poster carousel.
    static func sectionRowHeight(for traits: UITraitCollection) -> CGFloat {
        posterCardSize(for: traits).height + 56
    }

    // MARK: Banner / hero

    /// Home banner header height — proportional to the available height, clamped
    /// so it stays tall enough in landscape and not oversized on big iPads.
    static func bannerHeight(forAvailableHeight h: CGFloat) -> CGFloat {
        min(520, max(300, h * 0.5))
    }

    /// Detail screen hero image height — proportional, clamped.
    static func detailHeroHeight(forAvailableHeight h: CGFloat) -> CGFloat {
        min(560, max(280, h * 0.45))
    }

    // MARK: Character cells (Detail)

    static func characterCellSize(for traits: UITraitCollection) -> CGSize {
        isRegular(traits) ? CGSize(width: 104, height: 144) : CGSize(width: 80, height: 110)
    }

    static func characterAvatarDiameter(for traits: UITraitCollection) -> CGFloat {
        isRegular(traits) ? 88 : 64
    }

    // MARK: See All grid

    /// Number of grid columns for a given content width. Targets ~190pt per card
    /// (never fewer than 3) so iPhone shows 3, iPad portrait ~4, iPad landscape 5–6.
    static func gridColumns(forWidth width: CGFloat) -> Int {
        max(3, Int(width / 190))
    }
}
