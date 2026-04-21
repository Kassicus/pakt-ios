import SwiftUI

public struct PaktSectionHeader: View {
    private let title: String
    private let icon: String
    private let accent: Color

    public init(_ title: String, icon: String, accent: Color = .paktMutedForeground) {
        self.title = title
        self.icon = icon
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(paktIcon: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
            Text(title.uppercased())
                .font(.pakt(.small))
                .tracking(0.6)
                .foregroundStyle(Color.paktMutedForeground)
        }
        .textCase(nil)
        .padding(.leading, -4)
    }
}

#Preview("Section headers") {
    Form {
        Section { Text("Row") } header: {
            PaktSectionHeader("Status", icon: "activity", accent: .paktPrimary)
        }
        Section { Text("Row") } header: {
            PaktSectionHeader("Contents", icon: "package-open", accent: .paktStorage)
        }
        Section { Text("Row") } header: {
            PaktSectionHeader("Tags", icon: "tag", accent: .paktDonate)
        }
    }
}
