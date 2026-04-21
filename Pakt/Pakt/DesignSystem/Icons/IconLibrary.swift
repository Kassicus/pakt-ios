import SwiftUI

/// Lucide-icon-name → SF Symbol mapping. Unknown names fall back to "questionmark".
/// Web-side icon names come from `lucide-react`; keeping the key as the Lucide
/// slug makes it trivial to grep for parity with the web app.
public enum PaktIcon {
    public static let map: [String: String] = [
        // navigation tabs
        "package-open": "shippingbox",
        "shuffle":      "shuffle",
        "search":       "magnifyingglass",
        "box":          "cube.box",
        "scan-line":    "barcode.viewfinder",

        // common actions
        "plus":         "plus",
        "x":            "xmark",
        "trash":        "trash",
        "trash-2":      "trash",
        "edit":         "pencil",
        "edit-2":       "pencil",
        "pencil":       "pencil",
        "copy":         "doc.on.doc",
        "download":     "arrow.down.circle",
        "upload":       "arrow.up.circle",
        "share":        "square.and.arrow.up",

        // chevrons + indicators
        "chevron-right":"chevron.right",
        "chevron-left": "chevron.left",
        "chevron-down": "chevron.down",
        "chevron-up":   "chevron.up",
        "check":        "checkmark",
        "check-circle": "checkmark.circle.fill",

        // status + feedback
        "alert-triangle": "exclamationmark.triangle.fill",
        "loader-2":     "arrow.triangle.2.circlepath",
        "bell":         "bell",
        "info":         "info.circle",

        // feature-specific
        "camera":       "camera",
        "image":        "photo",
        "map-pin":      "mappin.and.ellipse",
        "truck":        "truck.box",
        "qr-code":      "qrcode",
        "settings":     "gearshape",
        "more-vertical":"ellipsis",
        "more-horizontal":"ellipsis",
        "log-out":      "rectangle.portrait.and.arrow.right",
        "user":         "person",
        "users":        "person.2",
        "home":         "house",

        // status + section affordances
        "activity":     "waveform.path.ecg",
        "file-text":    "doc.text",
        "lock":         "lock.fill",
        "sliders":      "slider.horizontal.3",
        "tag":          "tag",
        "circle":       "circle",
        "tray.full":    "tray.full.fill",
        "sparkles":     "sparkles",
    ]
}

public extension Image {
    init(paktIcon slug: String) {
        let symbol = PaktIcon.map[slug] ?? "questionmark"
        self.init(systemName: symbol)
    }
}
