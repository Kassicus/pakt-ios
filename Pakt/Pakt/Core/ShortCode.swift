import Foundation

public enum IDPrefix: String, Sendable, CaseIterable {
    case move = "mov"
    case room = "rm"
    case item = "itm"
    case photo = "ph"
    case box = "box"
    case boxItem = "bi"
    case checklist = "chk"
    case member = "mmb"
    case invitation = "inv"
    case boxType = "boxtyp"
}

public enum ShortCode {
    nonisolated private static let safeAlphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    nonisolated private static let standardAlphabet = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    nonisolated private static let inviteAlphabet = standardAlphabet

    public nonisolated static func generateBoxShortCode() -> String {
        "B-" + random(from: safeAlphabet, length: 4)
    }

    public nonisolated static func generateId(_ prefix: IDPrefix) -> String {
        "\(prefix.rawValue)_" + random(from: standardAlphabet, length: 10)
    }

    public nonisolated static func generateInviteToken() -> String {
        random(from: inviteAlphabet, length: 32)
    }

    /// Human-friendly short code for mobile invites. Uses the safe alphabet
    /// (no 0/O/1/I/L) so users can read and type it without confusion.
    public nonisolated static func generateInviteCode() -> String {
        "PAKT-" + random(from: safeAlphabet, length: 4)
    }

    private nonisolated static func random(from alphabet: [Character], length: Int) -> String {
        var out = String()
        out.reserveCapacity(length)
        for _ in 0..<length {
            out.append(alphabet[Int.random(in: 0..<alphabet.count)])
        }
        return out
    }
}
