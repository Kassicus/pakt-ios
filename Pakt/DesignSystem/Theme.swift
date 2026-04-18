import SwiftUI

/// Color tokens mirroring ~/Documents/github/pakt/src/app/globals.css.
/// OKLCH values are precomputed to sRGB; dynamic Color resolves per scheme.
public extension Color {
    // MARK: backgrounds
    static let paktBackground   = Color(light: .white,               dark: hex(0x0A0A0A))
    static let paktForeground   = Color(light: hex(0x0A0A0A),        dark: hex(0xFAFAFA))
    static let paktCard         = Color(light: .white,               dark: hex(0x0A0A0A))
    static let paktPopover      = Color(light: .white,               dark: hex(0x141414))

    // MARK: primary (violet)
    static let paktPrimary         = Color(light: hex(0x7B50E0),     dark: hex(0x9E7CF0))
    static let paktPrimaryForeground = Color(light: hex(0xFAFAFA),   dark: hex(0xFAFAFA))

    // MARK: secondary / muted / accent
    static let paktSecondary    = Color(light: hex(0xF5F5F5),        dark: hex(0x2E2E2E))
    static let paktSecondaryForeground = Color(light: hex(0x1A1A1A), dark: hex(0xFAFAFA))
    static let paktMuted        = Color(light: hex(0xF5F5F5),        dark: hex(0x2E2E2E))
    static let paktMutedForeground = Color(light: hex(0x737373),     dark: hex(0xA1A1A1))
    static let paktAccent       = Color(light: hex(0xF5F5F5),        dark: hex(0x3A2D60))
    static let paktAccentForeground = Color(light: hex(0x1A1A1A),    dark: hex(0xFAFAFA))

    // MARK: destructive (red)
    static let paktDestructive  = Color(light: hex(0xD63C2A),        dark: hex(0xE66B5A))

    // MARK: borders, inputs, rings
    static let paktBorder       = Color(light: hex(0xEBE6E6),        dark: Color.white.opacity(0.10))
    static let paktInput        = Color(light: hex(0xEBE6E6),        dark: Color.white.opacity(0.15))
    static let paktRing         = Color(light: hex(0x7B50E0).opacity(0.5),
                                        dark:  hex(0x9E7CF0).opacity(0.6))

    // MARK: semantic disposition tints
    static let paktMoving       = Color(light: hex(0x2C7A4B),        dark: hex(0x4BB478))
    static let paktStorage      = Color(light: hex(0x2F6AB0),        dark: hex(0x7FB3E8))
    static let paktDonate       = Color(light: hex(0xA86A1A),        dark: hex(0xE0A65B))
    static let paktTrash        = Color(light: hex(0xA12F2F),        dark: hex(0xE08080))
    static let paktSold         = Color(light: hex(0x5E4FA2),        dark: hex(0xB3A8E0))
    static let paktUndecided    = Color(light: hex(0x737373),        dark: hex(0xA1A1A1))
}

// MARK: - hex + dynamic color helpers

private func hex(_ v: UInt32) -> Color {
    let r = Double((v >> 16) & 0xFF) / 255.0
    let g = Double((v >>  8) & 0xFF) / 255.0
    let b = Double( v        & 0xFF) / 255.0
    return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
}

private extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
