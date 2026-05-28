import Foundation

// MARK: - APIConfiguration

/// Holds everything the client needs to know about your API before it sends
/// the first request: where to point, what headers to include by default,
/// how long to wait, and how to decode responses.
///
/// Create one instance per environment (prod, staging, mock server, etc.) and
/// inject it when you initialise `APIClient`. The client itself has no hardcoded
/// opinions about base URLs, auth schemes, or decoding strategies — all of that
/// lives here.
///
/// Example:
///
///     let config = APIConfiguration(
///         baseURL: URL(string: "https://api.myapp.com/v1")!,
///         defaultHeaders: [
///             "Content-Type": "application/json",
///             "Authorization": "Bearer \(token)"
///         ]
///     )
///
public struct APIConfiguration: @unchecked Sendable {

    /// The root URL every request path is appended to.
    public let baseURL: URL

    /// Headers included in every request. Individual requests can override
    /// or extend these via their own `headers` property.
    public let defaultHeaders: [String: String]

    /// How long a request can run before it's considered timed out.
    /// Defaults to 30 seconds.
    public let timeoutInterval: TimeInterval

    /// The decoder used for all responses. Swap this out if your API returns
    /// snake_case keys, custom date formats, or any non-default strategy.
    public let decoder: JSONDecoder

    public init(
        baseURL: URL,
        defaultHeaders: [String: String] = [
            "Content-Type": "application/json",
            "Accept":       "application/json"
        ],
        timeoutInterval: TimeInterval = 30,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.decoder = decoder
    }
}
