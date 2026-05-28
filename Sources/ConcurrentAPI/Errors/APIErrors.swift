import Foundation

// MARK: - APIError

/// Everything that can go wrong during a request, in one place.
///
/// When you call `send(_:)` directly, you catch these yourself. When you use
/// `sendConcurrently(_:)`, failures are wrapped inside `APIResult` rather than
/// thrown, so one bad request doesn't cancel the whole batch.
public enum APIError: Error, Sendable {

    /// The path couldn't be combined with the base URL into something valid.
    case invalidURL(String)

    /// The server responded, but with a status code outside the 2xx range.
    /// The raw response body is included so you can inspect the error payload.
    case httpError(statusCode: Int, data: Data)

    /// The response arrived but couldn't be decoded into the expected type.
    /// The underlying DecodingError tells you exactly which field caused it.
    case decodingFailed(underlying: String)

    /// Something went wrong at the network layer before a response arrived —
    /// no connectivity, DNS failure, SSL handshake, that sort of thing.
    case networkFailure(underlying: String)

    /// The task was cancelled before it could finish.
    case cancelled
}

// MARK: - Init helpers for wrapping errors

extension APIError {
    static func decodingFailed(_ error: any Error) -> APIError {
        .decodingFailed(underlying: error.localizedDescription)
    }

    static func networkFailure(_ error: any Error) -> APIError {
        .networkFailure(underlying: error.localizedDescription)
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Couldn't build a valid URL from path: \(path)"
        case .httpError(let code, _):
            return "Server returned HTTP \(code)"
        case .decodingFailed(let message):
            return "Response decoding failed: \(message)"
        case .networkFailure(let message):
            return "Network error: \(message)"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}
