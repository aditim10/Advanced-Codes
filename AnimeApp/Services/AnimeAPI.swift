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
