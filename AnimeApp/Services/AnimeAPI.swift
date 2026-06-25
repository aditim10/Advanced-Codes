//
//  AnimeAPI.swift
//  AnimeApp
//
//  The single shared `APIClient` every service talks through, plus a small
//  retry-with-backoff convenience layered on top of ConcurrentAPI. Jikan
//  rate-limits bursts (HTTP 429), so retrying transient failures keeps screens
//  like the featured banner reliably populated.
//

import Foundation
import ConcurrentAPI

// MARK: - AnimeAPI

/// Namespace owning the app-wide ``APIClient`` instance, configured for Jikan v4.
enum AnimeAPI {

    /// Shared client. All services default to this so requests share one actor
    /// (and one URLSession connection pool).
    static let client = APIClient(
        configuration: APIConfiguration(
            baseURL: APIConstants.baseURL,
            timeoutInterval: APIConstants.timeout
        )
    )
}

// MARK: - Retry helper

extension APIClient {

    /// Sends a request, retrying transient failures (HTTP 429 / 5xx / network
    /// blips) with linear back-off. Non-retryable errors are thrown immediately.
    ///
    /// - Parameters:
    ///   - request: The endpoint to call.
    ///   - maxRetries: Total attempts before giving up (defaults to
    ///     ``APIConstants/maxRetries``).
    func sendWithRetry<R: APIRequest>(
        _ request: R,
        maxRetries: Int = APIConstants.maxRetries
    ) async throws -> R.Response {
        var lastError: APIError = .cancelled

        for attempt in 0..<max(1, maxRetries) {
            if attempt > 0 {
                let seconds = APIConstants.retryBackoff * Double(attempt)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            do {
                return try await send(request)
            } catch let error as APIError {
                guard error.isRetryable else { throw error }
                lastError = error
            }
        }
        throw lastError
    }
}

// MARK: - Friendly error messages

/// Maps low-level networking errors to short, calm, user-facing copy so screens
/// can show smooth "something went wrong" states instead of raw system text like
/// "The operation couldn't be completed." Lives here because it needs to inspect
/// `ConcurrentAPI`'s `APIError`; callers pass a plain `Error?` and get a string.
enum APIErrorMessage {

    static func text(for error: Error?) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkFailure:
                return offline
            case .httpError(let code, _):
                if code == 429 { return rateLimited }
                if (500...599).contains(code) { return serverDown }
                return "Something went wrong (error \(code)). Please try again."
            default:
                return generic
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return offline
            case .timedOut:
                return "The request timed out. Please check your connection and try again."
            default:
                return generic
            }
        }
        return generic
    }

    static let offline = "You appear to be offline. Check your connection and try again."
    static let serverDown = "Our servers are taking a break. Please try again in a little while."
    static let rateLimited = "We're getting a lot of requests right now. Please try again in a moment."
    static let generic = "We couldn't load the latest anime. Please try again."
}

// MARK: - Retryability

extension APIError {

    /// `true` for transient failures (rate limiting / server hiccups) that are
    /// worth retrying. The `ConcurrentAPI` package leaves retry policy to the
    /// app, so we classify its errors here.
    var isRetryable: Bool {
        switch self {
        case .httpError(let code, _):
            return code == 429 || (500...599).contains(code)
        case .networkFailure:
            return true
        default:
            return false
        }
    }
}
