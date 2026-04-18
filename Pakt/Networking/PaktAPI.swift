import Foundation

public actor PaktAPI {
    private let baseURL: URL
    private let session: URLSession
    private let tokens: any TokenProviding
    private var refreshTask: Task<String?, Error>?

    public init(baseURL: URL, tokens: any TokenProviding, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.tokens = tokens
    }

    public func send<R>(_ endpoint: Endpoint<R>) async throws -> R {
        try await send(endpoint, alreadyRefreshed: false)
    }

    private func send<R>(_ endpoint: Endpoint<R>, alreadyRefreshed: Bool) async throws -> R {
        var request = try buildRequest(endpoint, token: try await tokens.currentToken())

        let (data, response) = try await perform(request: request)
        let http = response as? HTTPURLResponse

        switch http?.statusCode {
        case 200..<300:
            return try endpoint.decode(data)
        case 401 where !alreadyRefreshed:
            _ = try await refreshToken()
            return try await send(endpoint, alreadyRefreshed: true)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case let s?:
            throw APIError.server(status: s, message: String(data: data, encoding: .utf8))
        case nil:
            throw APIError.transport(URLError(.badServerResponse))
        }
    }

    private func refreshToken() async throws -> String? {
        if let task = refreshTask {
            return try await task.value
        }
        let task = Task { () -> String? in
            defer { Task { await self.clearRefreshTask() } }
            return try await tokens.refreshedToken()
        }
        refreshTask = task
        return try await task.value
    }

    private func clearRefreshTask() { refreshTask = nil }

    private func buildRequest<R>(_ endpoint: Endpoint<R>, token: String?) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                       resolvingAgainstBaseURL: false)!
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        guard let url = components.url else { throw APIError.transport(URLError(.badURL)) }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.httpBody = endpoint.body
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
    }
}
