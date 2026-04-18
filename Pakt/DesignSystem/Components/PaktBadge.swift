import SwiftUI

public enum PaktBadgeTone {
    case `default`, secondary, destructive, outline, ghost, link

    var background: Color {
        switch self {
        case .default:     return .paktPrimary
        case .secondary:   return .paktSecondary
        case .destructive: return .paktDestructive.opacity(0.12)
        case .outline, .ghost, .link: return .clear
        }
    }

    var foreground: Color {
        switch self {
        case .default:     return .paktPrimaryForeground
        case .secondary:   return .paktSecondaryForeground
        case .destructive: return .paktDestructive
        case .outline:     return .paktForeground
        case .ghost:       return .paktMutedForeground
        case .link:        return .paktPrimary
        }
    }

    var border: Color {
        self == .outline ? .paktBorder : .clear
    }
}

public struct PaktBadge: View {
    public let text: String
    public let tone: PaktBadgeTone

    public init(_ text: String, tone: PaktBadgeTone = .default) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(.pakt(.small))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(tone.foreground)
            .background(Capsule().fill(tone.background))
            .overlay(Capsule().strokeBorder(tone.border, lineWidth: tone == .outline ? 1 : 0))
    }
}
