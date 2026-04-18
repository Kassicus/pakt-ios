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
    private static let safeAlphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let standardAlphabet = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let inviteAlphabet = standardAlphabet

    public static func generateBoxShortCode() -> String {
        "B-" + random(from: safeAlphabet, length: 4)
    }

    public static func generateId(_ prefix: IDPrefix) -> String {
        "\(prefix.rawValue)_" + random(from: standardAlphabet, length: 10)
    }

    public static func generateInviteToken() -> String {
        random(from: inviteAlphabet, length: 32)
    }

    private static func random(from alphabet: [Character], length: Int) -> String {
        var out = String()
        out.reserveCapacity(length)
        for _ in 0..<length {
            out.append(alphabet[Int.random(in: 0..<alphabet.count)])
        }
        return out
    }
}
