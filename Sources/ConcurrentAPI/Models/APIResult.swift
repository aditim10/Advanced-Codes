import Foundation

// MARK: - APIResult

/// The outcome of a single request inside a concurrent batch.
///
/// `sendConcurrently(_:)` returns one of these per request instead of throwing,
/// so a failure on one endpoint doesn't cancel the others. Check `isSuccess`
/// for a quick gate, or switch on `outcome` if you need the full picture.
///
/// Example:
///
///     let results = await client.sendConcurrently(requests)
///
///     for result in results {
///         switch result.outcome {
///         case .success(let user):
///             print("Got user:", user.name)
///         case .failure(let error):
///             print("Failed [\(result.path)]:", error)
///         }
///     }
///
public struct APIResult<Response: Sendable>: Sendable {

    /// The path of the originating request. Useful for correlating results
    /// back to specific endpoints since batch completion order isn't guaranteed.
    public let path: String

    /// Whether the request succeeded or failed, with the associated value.
    public let outcome: Outcome

    public enum Outcome: Sendable {
        case success(Response)
        case failure(APIError)
    }
}

// MARK: - Convenience accessors

public extension APIResult {

    /// The decoded response if the request succeeded, otherwise `nil`.
    var value: Response? {
        if case .success(let v) = outcome { return v }
        return nil
    }

    /// The error if the request failed, otherwise `nil`.
    var error: APIError? {
        if case .failure(let e) = outcome { return e }
        return nil
    }

    /// `true` when the request completed successfully.
    var isSuccess: Bool { value != nil }
}

// MARK: - RawAPIResult

/// Returned by `sendConcurrentlyRaw(_:)` when you have a batch of requests
/// with different response types. Gives you the raw `Data` to decode yourself.
public struct RawAPIResult: Sendable {

    /// The path of the originating request, for correlating results.
    public let path: String

    /// The outcome — raw response data on success, an `APIError` on failure.
    public let outcome: Outcome

    public enum Outcome: Sendable {
        case success(Data)
        case failure(APIError)
    }

    /// The response data if the request succeeded, otherwise `nil`.
    public var data: Data? {
        if case .success(let d) = outcome { return d }
        return nil
    }

    /// The error if the request failed, otherwise `nil`.
    public var error: APIError? {
        if case .failure(let e) = outcome { return e }
        return nil
    }
}
