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
import AdSDK

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
        static var namePlaceholder: String { localized("login.name", "Full name") }
        static var emailPlaceholder: String { localized("login.email", "Email address") }
        static var passwordPlaceholder: String { localized("login.password", "Password") }
        static var signIn: String { localized("login.sign_in", "Sign In") }
        static var hint: String { localized("login.hint", "Demo: enter your name, any valid email + 6+ char password") }

        static var errorEmptyName: String { localized("login.error.empty_name", "Please enter your name.") }
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
        static var readMore: String { localized("detail.read_more", "Read more") }
        static var readLess: String { localized("detail.read_less", "Read less") }
    }

    // MARK: Ads
    enum Ads {
        static var preferencesTitle: String { localized("ads.preferences.title", "Ad Preferences") }
        static var preferencesMessage: String { localized("ads.preferences.message", "Choose how many ads play during videos.") }
        static var adLabel: String { localized("ads.label", "Ad") }
        static var skip: String { localized("ads.skip", "Skip Ad") }
        static var learnMore: String { localized("ads.learn_more", "Learn More") }

        /// e.g. "Skip in 5".
        static func skipIn(_ seconds: Int) -> String {
            localized("ads.skip_in", "Skip in \(seconds)")
        }

        /// e.g. "Ad 1 of 2".
        static func adOfCount(_ index: Int, _ count: Int) -> String {
            localized("ads.ad_of_count", "Ad \(index) of \(count)")
        }

        /// Localised, user-facing name for an ad tier.
        static func tierName(_ tier: AdTier) -> String {
            switch tier {
            case .adFree:      return localized("ads.tier.ad_free", "Ad-free")
            case .adLite:      return localized("ads.tier.ad_lite", "Ad-lite (fewer ads)")
            case .adSupported: return localized("ads.tier.ad_supported", "Ad-supported")
            }
        }
    }

    // MARK: Character detail
    enum Character {
        static var about: String { localized("character.about", "About") }
        static var voiceActors: String { localized("character.voice_actors", "Voice Actors") }
        static var alsoKnownAs: String { localized("character.also_known_as", "Also known as") }
        static var noAbout: String { localized("character.no_about", "No biography available for this character.") }

        /// e.g. "12,345 favorites".
        static func favorites(_ count: String) -> String {
            localized("character.favorites", "\(count) favorites")
        }
    }
}
