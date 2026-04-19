import Foundation

/// QR codes encode `pakt://box/<shortCode>`. Both the generator and scanner
/// agree on this format so `shortCode` is enough to look up the Box.
enum QRPayload {
    static let scheme = "pakt"
    static let host = "box"

    static func string(for shortCode: String) -> String {
        "\(scheme)://\(host)/\(shortCode)"
    }

    static func parseShortCode(from raw: String) -> String? {
        guard let url = URL(string: raw),
              url.scheme == scheme,
              url.host == host
        else { return nil }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? nil : path
    }
}
