//
//  LoginModels.swift
//  AnimeApp
//
//  VIP scene models for the Login module plus the app-wide `Session` helper.
//

import Foundation

enum Login {

    /// Sign-in use case.
    enum SignIn {
        struct Request {
            let email: String?
            let password: String?
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
    static func signIn(email: String) {
        UserDefaults.standard.set(email, forKey: StorageKey.loggedInEmail)
    }

    static func logout() {
        UserDefaults.standard.removeObject(forKey: StorageKey.loggedInEmail)
    }

    static var isLoggedIn: Bool {
        UserDefaults.standard.string(forKey: StorageKey.loggedInEmail) != nil
    }

    static var email: String? {
        UserDefaults.standard.string(forKey: StorageKey.loggedInEmail)
    }
}
