import Foundation
import Security

/// Thin Keychain wrapper — only used to persist the Apple user identifier.
/// Generic password item scoped by the app's bundle via the default access group.
enum Keychain {
    static let service = "com.kasonsuchow.Pakt.auth"

    static func setString(_ value: String?, for key: String) {
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(baseQuery as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var attrs = baseQuery
        attrs[kSecValueData] = data
        attrs[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func getString(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }
}
