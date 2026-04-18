import Foundation

public enum APIError: Error, LocalizedError {
    case notAuthenticated
    case unauthorized
    case notFound
    case server(status: Int, message: String?)
    case decoding(DecodingError)
    case transport(Error)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You're signed out."
        case .unauthorized:     return "Session expired. Sign in again."
        case .notFound:         return "Not found."
        case .server(let s, let m): return "Server error \(s)\(m.map { ": \($0)" } ?? "")"
        case .decoding:         return "Response format didn't match."
        case .transport(let e): return e.localizedDescription
        }
    }
}
