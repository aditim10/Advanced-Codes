import Foundation

// MARK: - APIRequest

/// The contract every endpoint in your app should conform to.
///
/// Define one struct per endpoint. Only `path` is required — everything else
/// has a sensible default so GET requests with no body stay one-liners.
///
/// Example:
///
///     struct GetUserRequest: APIRequest {
///         typealias Response = User
///         let userID: Int
///         var path: String { "users/\(userID)" }
///     }
///
///     struct CreatePostRequest: APIRequest {
///         typealias Response = Post
///         var path: String { "posts" }
///         var method: HTTPMethod { .post }
///         var body: (any Encodable)? { payload }
///         let payload: NewPost
///     }
///
/// `Response` must be `Decodable & Sendable` so it can safely travel across
/// task boundaries when you use the concurrent batch methods on `APIClient`.
public protocol APIRequest: Sendable {
    associatedtype Response: Decodable & Sendable

    /// The path component appended to the client's base URL, e.g. `"users/42"`.
    var path: String { get }

    /// HTTP method. Defaults to `.get`.
    var method: HTTPMethod { get }

    /// Query parameters appended to the URL. Defaults to `nil`.
    var queryItems: [URLQueryItem]? { get }

    /// Per-request headers merged on top of the client's default headers.
    /// Any key here overrides the same key in the defaults. Defaults to `nil`.
    var headers: [String: String]? { get }

    /// Optional request body. Encoded as JSON. Defaults to `nil`.
    var body: (any Encodable)? { get }
}

public extension APIRequest {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String: String]? { nil }
    var body: (any Encodable)? { nil }
}
