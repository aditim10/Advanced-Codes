//
//  LoginModels.swift
//  AnimeApp
//
//  VIP scene models for the Login module plus the app-wide `Session` helper.
//

import Foundation
import AdSDK

enum Login {

    /// Sign-in use case.
    enum SignIn {
        struct Request {
            let email: String?
            let password: String?
            let name: String?

            init(email: String?, password: String?, name: String? = nil) {
                self.email = email
                self.password = password
                self.name = name
            }
        }
        struct Response {
            enum Outcome {
                case success(email: String)
                case failure(reason: String)
            }
            let outcome: Outcome
        }
    }

    /// Dumb snapshot the View renders for a validation/auth failure.
    struct ErrorViewModel {
        let message: String
    }
}

// MARK: - Session

/// App-wide authentication state, backed by `UserDefaults`. Kept tiny and
/// UIKit-free so it can be read from the AppDelegate, routers, etc.
enum Session {
    static func signIn(email: String, name: String) {
        UserDefaults.standard.set(email, forKey: StorageKey.loggedInEmail)
        UserDefaults.standard.set(name, forKey: StorageKey.userName)
    }

    static func logout() {
        UserDefaults.standard.removeObject(forKey: StorageKey.loggedInEmail)
        UserDefaults.standard.removeObject(forKey: StorageKey.userName)
    }

    static var isLoggedIn: Bool {
        UserDefaults.standard.string(forKey: StorageKey.loggedInEmail) != nil
    }

    static var email: String? {
        UserDefaults.standard.string(forKey: StorageKey.loggedInEmail)
    }

    /// The display name the user entered at sign-in.
    static var name: String? {
        UserDefaults.standard.string(forKey: StorageKey.userName)
    }

    /// Best display name for UI: the entered name, falling back to the email's
    /// local part, then a generic label.
    static var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let email, let local = email.split(separator: "@").first { return String(local) }
        return "Guest"
    }

    /// The viewer's chosen advertising tier, persisted across launches. Defaults
    /// to `.adSupported`. Drives how many mid-roll breaks/ads play in the custom
    /// player (see `AdSDK`).
    static var adTier: AdTier {
        get {
            guard let raw = UserDefaults.standard.string(forKey: StorageKey.adTier),
                  let tier = AdTier(rawValue: raw) else { return .adSupported }
            return tier
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: StorageKey.adTier) }
    }

    /// A stable, anonymous identifier for the current install/user, created lazily
    /// on first access and persisted. Use this (not the email) for analytics so we
    /// never hand raw PII to third-party tools — see the GDPR note on
    /// `LoginAnalyticsEvent`.
    static var analyticsUserID: String {
        if let existing = UserDefaults.standard.string(forKey: StorageKey.analyticsUserID) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: StorageKey.analyticsUserID)
        return new
    }
}
