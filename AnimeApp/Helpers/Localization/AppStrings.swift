//
//  AppStrings.swift
//
//  Centralised, type-safe access to every user-facing string.
//
//  Each value pairs a localization *key* (looked up in Localizable.strings) with
//  an English *default* in the same place, so call sites stay readable
//  (`AppStrings.Login.signIn`) and the app still shows proper English even if a
//  translation is missing. Add new languages by adding `<lang>.lproj`.
//

import Foundation

/// Small helper that wraps `NSLocalizedString` with an inline English default.
@inline(__always)
private func localized(_ key: String, _ defaultValue: String) -> String {
    NSLocalizedString(key, value: defaultValue, comment: "")
}

// MARK: - AppStrings

/// Namespace for all localized strings, grouped by feature/screen.
enum AppStrings {

    // MARK: Common
    enum Common {
        static var ok: String { localized("common.ok", "OK") }
        static var cancel: String { localized("common.cancel", "Cancel") }
        static var retry: String { localized("common.retry", "Retry") }
        static var error: String { localized("common.error", "Error") }
        static var oops: String { localized("common.oops", "Oops") }
        static var seeAll: String { localized("common.see_all", "See all") }
    }

    // MARK: Login
    enum Login {
        static var tagline: String { localized("login.tagline", "Unlimited anime. Any time.") }
        static var emailPlaceholder: String { localized("login.email", "Email address") }
        static var passwordPlaceholder: String { localized("login.password", "Password") }
        static var signIn: String { localized("login.sign_in", "Sign In") }
        static var hint: String { localized("login.hint", "Demo: any valid email + 6+ char password") }

        static var errorEmptyEmail: String { localized("login.error.empty_email", "Please enter your email.") }
        static var errorInvalidEmail: String { localized("login.error.invalid_email", "Please enter a valid email address.") }
        static var errorEmptyPassword: String { localized("login.error.empty_password", "Please enter your password.") }
        static var errorShortPassword: String { localized("login.error.short_password", "Password must be at least 6 characters.") }
    }

    // MARK: Home
    enum Home {
        static var brand: String { localized("home.brand", "ANIMEX") }
    }

    // MARK: Search
    enum Search {
        static var placeholder: String { localized("search.placeholder", "Search anime…") }
        static var discoverTitle: String { localized("search.discover.title", "Discover anime") }
        static var discoverSubtitle: String { localized("search.discover.subtitle", "Search by title to find shows and movies.") }
        static var noResultsTitle: String { localized("search.no_results.title", "No results") }
        static var noResultsSubtitle: String { localized("search.no_results.subtitle", "Try a different title or check the spelling.") }
    }

    // MARK: Detail
    enum Detail {
        static var characters: String { localized("detail.characters", "Characters") }
        static var synopsis: String { localized("detail.synopsis", "Synopsis") }
        static var watchNow: String { localized("detail.watch_now", "▶  Watch Now") }
        static var noSynopsis: String { localized("detail.no_synopsis", "No synopsis available.") }
    }
}
