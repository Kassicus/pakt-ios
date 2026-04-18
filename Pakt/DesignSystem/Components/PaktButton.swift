import SwiftUI

public enum PaktButtonVariant {
    case `default`, outline, secondary, ghost, destructive, link
}

public enum PaktButtonSize {
    case xs, sm, `default`, lg, icon, iconSm, iconLg

    var height: CGFloat {
        switch self {
        case .xs, .iconSm: return 24
        case .sm:          return 28
        case .default, .icon: return 32
        case .lg, .iconLg: return 36
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .icon, .iconSm, .iconLg: return 0
        case .xs: return 8
        case .sm, .default, .lg: return 10
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .xs, .iconSm: return PaktRadius.md
        case .sm:          return min(PaktRadius.md + 4, 12)
        case .default, .lg, .icon, .iconLg: return PaktRadius.lg
        }
    }

    var font: PaktFont {
        switch self {
        case .xs: return .small
        default:  return .body
        }
    }

    var isIcon: Bool { self == .icon || self == .iconSm || self == .iconLg }
}

public struct PaktButtonStyle: ButtonStyle {
    public let variant: PaktButtonVariant
    public let size: PaktButtonSize

    public init(variant: PaktButtonVariant = .default, size: PaktButtonSize = .default) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pakt(size.font))
            .padding(.horizontal, size.horizontalPadding)
            .frame(minHeight: size.height)
            .frame(minWidth: size.isIcon ? size.height : nil)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(background(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: variant == .outline ? 1 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(PaktMotion.quick, value: configuration.isPressed)
            .contentShape(Rectangle())
    }

    private func background(isPressed: Bool) -> Color {
        switch variant {
        case .default:     return isPressed ? .paktPrimary.opacity(0.9)   : .paktPrimary
        case .destructive: return isPressed ? .paktDestructive.opacity(0.18) : .paktDestructive.opacity(0.12)
        case .secondary:   return isPressed ? .paktSecondary.opacity(0.7) : .paktSecondary
        case .outline:     return isPressed ? .paktAccent.opacity(0.8)    : .clear
        case .ghost:       return isPressed ? .paktAccent.opacity(0.8)    : .clear
        case .link:        return .clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .default:     return .paktPrimaryForeground
        case .destructive: return .paktDestructive
        case .secondary:   return .paktSecondaryForeground
        case .outline, .ghost: return .paktForeground
        case .link:        return .paktPrimary
        }
    }

    private var borderColor: Color {
        variant == .outline ? .paktBorder : .clear
    }
}

public struct PaktButton<Label: View>: View {
    private let action: () -> Void
    private let variant: PaktButtonVariant
    private let size: PaktButtonSize
    private let label: Label

    public init(
        variant: PaktButtonVariant = .default,
        size: PaktButtonSize = .default,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) { label }
            .buttonStyle(PaktButtonStyle(variant: variant, size: size))
    }
}

public extension PaktButton where Label == Text {
    init(
        _ title: String,
        variant: PaktButtonVariant = .default,
        size: PaktButtonSize = .default,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.size = size
        self.action = action
        self.label = Text(title)
    }
}
