import SwiftUI

public struct DispositionTone {
    public static func badgeTone(for raw: String) -> PaktBadgeTone {
        switch raw {
        case "moving":    return .default
        case "storage":   return .secondary
        case "donate":    return .secondary
        case "trash":     return .destructive
        case "sold":      return .outline
        case "undecided": return .ghost
        default:          return .outline
        }
    }

    public static func label(for raw: String) -> String {
        switch raw {
        case "moving":    return "Moving"
        case "storage":   return "Storage"
        case "donate":    return "Donate"
        case "trash":     return "Trash"
        case "sold":      return "Sold"
        case "undecided": return "Undecided"
        default:          return raw.capitalized
        }
    }
}

public struct DispositionChip: View {
    public let disposition: String

    public init(disposition: String) { self.disposition = disposition }

    public var body: some View {
        PaktBadge(DispositionTone.label(for: disposition),
                  tone: DispositionTone.badgeTone(for: disposition))
    }
}
