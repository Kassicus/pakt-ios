import Foundation

public enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

/// A typed network endpoint. `Response` is what the caller receives; `Never` (or `Empty`)
/// is used for no-content endpoints.
public struct Endpoint<Response> {
    public let path: String
    public let method: HTTPMethod
    public let query: [URLQueryItem]
    public let body: Data?
    public let decode: (Data) throws -> Response

    public init(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        decode: @escaping (Data) throws -> Response
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.decode = decode
    }
}

public struct Empty: Decodable, Sendable {}

public extension Endpoint where Response: Decodable {
    init(path: String, method: HTTPMethod = .get, query: [URLQueryItem] = [], body: Data? = nil) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.decode = { try JSONCoders.decoder.decode(Response.self, from: $0) }
    }
}

public extension Endpoint where Response == Empty {
    static func empty(path: String, method: HTTPMethod, body: Data? = nil) -> Endpoint<Empty> {
        Endpoint(path: path, method: method, body: body) { _ in Empty() }
    }
}

public func encodeBody<T: Encodable>(_ value: T) throws -> Data {
    try JSONCoders.encoder.encode(value)
}
