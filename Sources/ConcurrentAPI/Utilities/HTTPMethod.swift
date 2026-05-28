import Foundation

// MARK: - HTTPMethod

/// Standard HTTP verbs. Extend this if your API uses something less common.
public enum HTTPMethod: String, Sendable {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case patch  = "PATCH"
    case delete = "DELETE"
}
