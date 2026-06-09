import Foundation

// MARK: - URLRequestBuilder

// Internal only — callers never interact with this directly.
// Keeps all the URL construction and header merging out of APIClient.
struct URLRequestBuilder {

    private let configuration: APIConfiguration

    init(configuration: APIConfiguration) {
        self.configuration = configuration
    }

    func build<R: APIRequest>(from request: R) throws -> URLRequest {
        // Combine base URL + path, then attach any query items
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: true
        ) else {
            throw APIError.invalidURL(request.path)
        }

        if let items = request.queryItems, !items.isEmpty {
            components.queryItems = items
        }

        guard let url = components.url else {
            throw APIError.invalidURL(request.path)
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: configuration.timeoutInterval)
        urlRequest.httpMethod = request.method.rawValue

        // Merge headers: client defaults first, then request-level values on top.
        // This means a request can override Authorization or Content-Type if needed.
        var merged = configuration.defaultHeaders
        request.headers?.forEach { merged[$0] = $1 }
        merged.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }

        // Encode the body if the request provided one
        if let body = request.body {
            urlRequest.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        return urlRequest
    }
}

// MARK: - AnyEncodable

// Type-eraser so we can encode `any Encodable` without the compiler complaining
// about opening existentials. Just forwards the call to the real encode method.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        _encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
