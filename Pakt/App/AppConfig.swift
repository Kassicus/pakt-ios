import Foundation

/// Read from Info.plist so we can swap per-environment (Debug vs Release) without rebuilding.
/// Set these keys in the Pakt target's Info: `ClerkPublishableKey`, `PaktAPIBaseURL`.
enum AppConfig {
    static let clerkPublishableKey: String = {
        let fromEnv = ProcessInfo.processInfo.environment["CLERK_PUBLISHABLE_KEY"]
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String
        return fromEnv ?? fromPlist ?? ""
    }()

    static let apiBaseURL: URL = {
        let fromEnv = ProcessInfo.processInfo.environment["PAKT_API_BASE_URL"]
        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "PaktAPIBaseURL") as? String
        let str = fromEnv ?? fromPlist ?? "http://localhost:8080"
        return URL(string: str) ?? URL(string: "http://localhost:8080")!
    }()
}
