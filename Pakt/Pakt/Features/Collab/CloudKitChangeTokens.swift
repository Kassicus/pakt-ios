import CloudKit
import Foundation

/// Persistence for `CKServerChangeToken`s used by incremental CloudKit fetches.
///
/// Tokens are stored as archived `Data` blobs in `UserDefaults`, keyed per
/// zone name and per database scope. Losing a token is safe — it just forces
/// the next fetch to pull from scratch.
public enum CloudKitChangeTokens {
    private static let defaults = UserDefaults.standard

    // MARK: - Zone tokens

    public static func zoneKey(_ zoneName: String) -> String {
        "cktoken.zone.\(zoneName).v1"
    }

    public static func zoneToken(for zoneName: String) -> CKServerChangeToken? {
        decode(defaults.data(forKey: zoneKey(zoneName)))
    }

    public static func setZoneToken(_ token: CKServerChangeToken?, for zoneName: String) {
        let key = zoneKey(zoneName)
        if let token, let data = encode(token) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Database-scope tokens

    public enum DatabaseScopeKey: String {
        case `private` = "private"
        case shared = "shared"

        public var key: String { "cktoken.db.\(rawValue).v1" }
    }

    public static func databaseToken(scope: DatabaseScopeKey) -> CKServerChangeToken? {
        decode(defaults.data(forKey: scope.key))
    }

    public static func setDatabaseToken(_ token: CKServerChangeToken?, scope: DatabaseScopeKey) {
        if let token, let data = encode(token) {
            defaults.set(data, forKey: scope.key)
        } else {
            defaults.removeObject(forKey: scope.key)
        }
    }

    // MARK: - Subscription flags

    /// Records whether a subscription for a zone/scope has already been
    /// installed, so we don't spam CloudKit with duplicate create attempts.
    public static func hasInstalledZoneSubscription(zoneName: String) -> Bool {
        defaults.bool(forKey: "cksub.zone.\(zoneName).v1")
    }

    public static func markZoneSubscriptionInstalled(zoneName: String) {
        defaults.set(true, forKey: "cksub.zone.\(zoneName).v1")
    }

    public static func clearZoneSubscription(zoneName: String) {
        defaults.removeObject(forKey: "cksub.zone.\(zoneName).v1")
    }

    public static func hasInstalledSharedDBSubscription() -> Bool {
        defaults.bool(forKey: "cksub.db.shared.v1")
    }

    public static func markSharedDBSubscriptionInstalled() {
        defaults.set(true, forKey: "cksub.db.shared.v1")
    }

    // MARK: - Encoding helpers

    private static func encode(_ token: CKServerChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
    }

    private static func decode(_ data: Data?) -> CKServerChangeToken? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: data
        )
    }
}
