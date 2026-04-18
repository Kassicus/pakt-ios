import ClerkKit
import Foundation

/// Bridges Clerk's session token into the `PaktAPI` actor.
/// On 401 the API asks for a fresh token; we map that to a Clerk refresh.
public protocol TokenProviding: Sendable {
    func currentToken() async throws -> String?
    func refreshedToken() async throws -> String?
}

public struct ClerkTokenProvider: TokenProviding {
    public init() {}

    public func currentToken() async throws -> String? {
        try await Clerk.shared.auth.getToken()
    }

    public func refreshedToken() async throws -> String? {
        // Forcing a refresh = get a brand-new JWT from Clerk, bypassing cache.
        try await Clerk.shared.auth.getToken(.init(skipCache: true))
    }
}
