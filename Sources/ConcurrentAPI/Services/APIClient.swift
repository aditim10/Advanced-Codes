import Foundation

// MARK: - HTTPSessionProtocol

/// Internal protocol so tests can inject a mock without subclassing URLSession.
/// URLSession conforms to this automatically via the extension below.
protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}

// MARK: - APIClient

/// A generic, thread-safe HTTP client built on Swift Concurrency.
///
/// `APIClient` is an actor, so its internal state is protected without any
/// manual locking. Configure it once with an `APIConfiguration` and then
/// call one of three methods depending on what you need:
///
/// - `send(_:)` for a single request that throws on failure.
/// - `sendConcurrently(_:)` for a batch of same-type requests where you want
///   per-result outcomes rather than an all-or-nothing throw.
/// - `sendConcurrentlyRaw(_:)` for a mixed batch of different request types,
///   returning raw `Data` so you can decode each result into its own type.
///
/// Example — single request:
///
///     let client = APIClient(configuration: config)
///     let user = try await client.send(GetUserRequest(id: 42))
///
/// Example — concurrent batch:
///
///     let requests = userIDs.map { GetUserRequest(id: $0) }
///     let results = await client.sendConcurrently(requests)
///     let users = results.compactMap(\.value)
///
public actor APIClient {

    // MARK: Private state

    private let configuration: APIConfiguration
    private let session: any HTTPSession
    private let builder: URLRequestBuilder

    // MARK: Init

    /// Creates a new client.
    ///
    /// - Parameters:
    ///   - configuration: Base URL, default headers, timeout, and decoder.
    ///   - session: The URL session to use. Defaults to `URLSession.shared`.
    ///     Pass a mock in tests via the internal `HTTPSession` protocol.
    public init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.builder = URLRequestBuilder(configuration: configuration)
    }

    /// Internal init that accepts any `HTTPSession` — used by tests.
    init(configuration: APIConfiguration, httpSession: any HTTPSession) {
        self.configuration = configuration
        self.session = httpSession
        self.builder = URLRequestBuilder(configuration: configuration)
    }

    // MARK: - Public methods

    /// Sends a single request and returns the decoded response.
    ///
    /// Throws `APIError` if anything goes wrong — bad URL, non-2xx status,
    /// decoding failure, network error, or cancellation.
    ///
    /// - Parameter request: Any type conforming to `APIRequest`.
    /// - Returns: The decoded `Response` associated with your request type.
    public func send<R: APIRequest>(_ request: R) async throws -> R.Response {
        let urlRequest = try builder.build(from: request)
        return try await execute(urlRequest, decodingAs: R.Response.self)
    }

    /// Sends multiple requests of the same type concurrently and collects
    /// the results, one per request.
    ///
    /// This method never throws. Each `APIResult` in the returned array carries
    /// either a decoded response or an `APIError`, so a single failure doesn't
    /// affect the rest of the batch.
    ///
    /// The result order is not guaranteed to match the input order, since tasks
    /// finish as soon as they're done. Use `APIResult.path` to correlate results
    /// back to specific requests if ordering matters.
    ///
    /// - Parameter requests: An array of requests sharing the same `Response` type.
    /// - Returns: One `APIResult` per request, in completion order.
    public func sendConcurrently<R: APIRequest>(
        _ requests: [R]
    ) async -> [APIResult<R.Response>] {
        await withTaskGroup(of: APIResult<R.Response>.self) { group in
            for request in requests {
                group.addTask {
                    await self.performSingle(request)
                }
            }
            var results: [APIResult<R.Response>] = []
            results.reserveCapacity(requests.count)
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    /// Sends a mixed batch of requests with different response types concurrently,
    /// returning raw `Data` for each so you can decode them yourself.
    ///
    /// Use this when your batch contains requests that return different model types
    /// and you can't express them under a single generic constraint. Each
    /// `RawAPIResult` gives you the path it came from and either the raw `Data`
    /// or an `APIError`.
    ///
    /// - Parameter requests: Any mix of `APIRequest`-conforming types.
    /// - Returns: One `RawAPIResult` per request, in completion order.
    public func sendConcurrentlyRaw(
        _ requests: [any APIRequest]
    ) async -> [RawAPIResult] {
        await withTaskGroup(of: RawAPIResult.self) { group in
            for request in requests {
                group.addTask {
                    await self.performRaw(request)
                }
            }
            var results: [RawAPIResult] = []
            results.reserveCapacity(requests.count)
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - Private helpers

    // Core execution path shared by all public methods.
    // Handles status code validation, decoding, and error mapping in one place.
    private func execute<T: Decodable & Sendable>(
        _ urlRequest: URLRequest,
        decodingAs type: T.Type
    ) async throws -> T {
        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.networkFailure(URLError(.badServerResponse))
            }

            guard (200..<300).contains(http.statusCode) else {
                throw APIError.httpError(statusCode: http.statusCode, data: data)
            }

            do {
                return try configuration.decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed(error)
            }

        } catch let error as APIError {
            throw error
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.networkFailure(error)
        }
    }

    // Wraps a typed request in an APIResult so sendConcurrently never throws.
    private func performSingle<R: APIRequest>(
        _ request: R
    ) async -> APIResult<R.Response> {
        do {
            let urlRequest = try builder.build(from: request)
            let response = try await execute(urlRequest, decodingAs: R.Response.self)
            return APIResult(path: request.path, outcome: .success(response))
        } catch let error as APIError {
            return APIResult(path: request.path, outcome: .failure(error))
        } catch {
            return APIResult(path: request.path, outcome: .failure(.networkFailure(error)))
        }
    }

    // Like performSingle but returns raw Data, used by sendConcurrentlyRaw
    // where each request has a different Response type.
    private func performRaw(_ request: any APIRequest) async -> RawAPIResult {
        do {
            let urlRequest = try builder.build(from: request)
            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse else {
                return RawAPIResult(
                    path: request.path,
                    outcome: .failure(.networkFailure(URLError(.badServerResponse)))
                )
            }
            guard (200..<300).contains(http.statusCode) else {
                return RawAPIResult(
                    path: request.path,
                    outcome: .failure(.httpError(statusCode: http.statusCode, data: data))
                )
            }
            return RawAPIResult(path: request.path, outcome: .success(data))

        } catch let error as APIError {
            return RawAPIResult(path: request.path, outcome: .failure(error))
        } catch is CancellationError {
            return RawAPIResult(path: request.path, outcome: .failure(.cancelled))
        } catch {
            return RawAPIResult(path: request.path, outcome: .failure(.networkFailure(error)))
        }
    }
}
