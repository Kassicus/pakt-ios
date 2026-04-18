import SwiftUI
import UIKit

/// Font styles mirroring the shadcn/Tailwind scale used on the web.
/// Geist fonts must be registered in Info.plist via UIAppFonts and dropped
/// into Resources/Fonts/. Registration via `Fonts.registerIfNeeded()` is
/// defensive so previews without the bundled files fall back to system.
public enum PaktFont {
    case title           // 24 / semibold
    case heading         // 18 / medium
    case body            // 14 / regular
    case bodyMedium      // 14 / medium
    case small           // 12 / medium
    case mono            // 14 / mono regular
    case hero            // 48 / semibold (landing screens)

    public var size: CGFloat {
        switch self {
        case .title: return 24
        case .heading: return 18
        case .body, .bodyMedium, .mono: return 14
        case .small: return 12
        case .hero: return 48
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .title, .hero: return .semibold
        case .heading, .bodyMedium, .small: return .medium
        case .body, .mono: return .regular
        }
    }
}

public extension Font {
    static func pakt(_ style: PaktFont) -> Font {
        let family = (style == .mono) ? "GeistMono" : "Geist"
        if Fonts.available(family) {
            return Font.custom(family, size: style.size).weight(style.weight)
        }
        return Font.system(size: style.size, weight: style.weight,
                           design: style == .mono ? .monospaced : .default)
    }
}

public enum Fonts {
    public static func registerIfNeeded() {
        registerIfNeeded.wrappedValue
    }

    private static let registerIfNeeded: Box<Void> = Box {
        let names = [
            "Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold",
            "GeistMono-Regular", "GeistMono-Medium",
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func available(_ family: String) -> Bool {
        !UIFont.fontNames(forFamilyName: family).isEmpty
    }

    private final class Box<V> {
        let wrappedValue: V
        init(_ build: () -> V) { self.wrappedValue = build() }
    }
}
