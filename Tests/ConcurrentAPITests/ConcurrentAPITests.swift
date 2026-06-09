import XCTest
@testable import ConcurrentAPI

// MARK: - Stub model types

private struct Post: Codable, Sendable, Equatable {
    let id: Int
    let title: String
}

private struct Comment: Codable, Sendable, Equatable {
    let id: Int
    let body: String
}

// MARK: - Sample request definitions

private struct GetPost: APIRequest {
    typealias Response = Post
    let id: Int
    var path: String { "posts/\(id)" }
}

private struct GetComment: APIRequest {
    typealias Response = Comment
    let id: Int
    var path: String { "comments/\(id)" }
}

// MARK: - Mock session

// Conforms to the internal HTTPSession protocol instead of subclassing URLSession.
// URLSession's data(for:) method isn't open, so subclassing it to override
// doesn't work outside the framework — using a protocol avoids that entirely.
private final class MockHTTPSession: HTTPSession, @unchecked Sendable {
    var handler: (URLRequest) async throws -> (Data, URLResponse) = { _ in
        throw URLError(.notConnectedToInternet)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

// MARK: - Helpers

private func makeConfig(base: String = "https://api.example.com") -> APIConfiguration {
    APIConfiguration(baseURL: URL(string: base)!)
}

private func makeClient(session: MockHTTPSession) -> APIClient {
    APIClient(configuration: makeConfig(), httpSession: session)
}

private func okResponse(url: URL, status: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}

// MARK: - Tests

final class APIClientTests: XCTestCase {

    // MARK: send(_:) — single request

    func test_send_successfullyDecodesResponse() async throws {
        let session = MockHTTPSession()
        let expected = Post(id: 1, title: "Hello")
        session.handler = { req in
            let data = try JSONEncoder().encode(expected)
            return (data, okResponse(url: req.url!))
        }
        let result = try await makeClient(session: session).send(GetPost(id: 1))
        XCTAssertEqual(result, expected)
    }

    func test_send_throwsHTTPErrorOnNon2xx() async {
        let session = MockHTTPSession()
        session.handler = { req in (Data(), okResponse(url: req.url!, status: 404)) }
        do {
            _ = try await makeClient(session: session).send(GetPost(id: 99))
            XCTFail("Expected APIError.httpError to be thrown")
        } catch APIError.httpError(let code, _) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_send_throwsDecodingFailedOnBadJSON() async {
        let session = MockHTTPSession()
        session.handler = { req in (Data("not json".utf8), okResponse(url: req.url!)) }
        do {
            _ = try await makeClient(session: session).send(GetPost(id: 1))
            XCTFail("Expected APIError.decodingFailed to be thrown")
        } catch APIError.decodingFailed {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: sendConcurrently(_:) — homogeneous batch

    func test_sendConcurrently_allSucceed() async {
        let session = MockHTTPSession()
        session.handler = { req in
            let id = Int(req.url!.lastPathComponent)!
            let data = try JSONEncoder().encode(Post(id: id, title: "Post \(id)"))
            return (data, okResponse(url: req.url!))
        }
        let results = await makeClient(session: session)
            .sendConcurrently((1...5).map { GetPost(id: $0) })

        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.isSuccess })
    }

    func test_sendConcurrently_partialFailures() async {
        let session = MockHTTPSession()
        session.handler = { req in
            let id = Int(req.url!.lastPathComponent)!
            if id % 2 == 0 {
                return (Data(), okResponse(url: req.url!, status: 500))
            }
            let data = try JSONEncoder().encode(Post(id: id, title: "Post \(id)"))
            return (data, okResponse(url: req.url!))
        }
        let results = await makeClient(session: session)
            .sendConcurrently((1...4).map { GetPost(id: $0) })

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results.filter { $0.isSuccess }.count, 2)
        XCTAssertEqual(results.filter { $0.error != nil }.count, 2)
    }

    // MARK: sendConcurrentlyRaw(_:) — heterogeneous batch

    func test_sendConcurrentlyRaw_mixedRequestTypes() async throws {
        let session = MockHTTPSession()
        session.handler = { req in
            if req.url!.path.contains("posts") {
                let data = try JSONEncoder().encode(Post(id: 1, title: "Title"))
                return (data, okResponse(url: req.url!))
            } else {
                let data = try JSONEncoder().encode(Comment(id: 1, body: "Body"))
                return (data, okResponse(url: req.url!))
            }
        }
        let results = await makeClient(session: session)
            .sendConcurrentlyRaw([GetPost(id: 1), GetComment(id: 1)])

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.data != nil })

        let postResult = try XCTUnwrap(results.first { $0.path.contains("posts") })
        let post = try JSONDecoder().decode(Post.self, from: XCTUnwrap(postResult.data))
        XCTAssertEqual(post.title, "Title")
    }

    // MARK: URL construction

    func test_queryItemsAppendedToURL() async throws {
        struct SearchRequest: APIRequest {
            typealias Response = Post
            var path: String { "search" }
            var queryItems: [URLQueryItem]? { [.init(name: "q", value: "swift")] }
        }
        var capturedURL: URL?
        let session = MockHTTPSession()
        session.handler = { req in
            capturedURL = req.url
            let data = try JSONEncoder().encode(Post(id: 0, title: ""))
            return (data, okResponse(url: req.url!))
        }
        _ = try await makeClient(session: session).send(SearchRequest())
        XCTAssertEqual(capturedURL?.query, "q=swift")
    }

    func test_requestHeadersOverrideDefaults() async throws {
        struct AuthRequest: APIRequest {
            typealias Response = Post
            var path: String { "me" }
            var headers: [String: String]? { ["Authorization": "Bearer token123"] }
        }
        var capturedAuth: String?
        let session = MockHTTPSession()
        session.handler = { req in
            capturedAuth = req.value(forHTTPHeaderField: "Authorization")
            let data = try JSONEncoder().encode(Post(id: 0, title: ""))
            return (data, okResponse(url: req.url!))
        }
        _ = try await makeClient(session: session).send(AuthRequest())
        XCTAssertEqual(capturedAuth, "Bearer token123")
    }
}
