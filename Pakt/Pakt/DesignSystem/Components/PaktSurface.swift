import SwiftUI

/// Card primitive with an accent leading bar and optional titled header.
/// This is the "section" replacement for screens refactored away from `Form`.
public struct PaktSurface<Content: View>: View {
    private let title: String?
    private let icon: String?
    private let accent: Color
    private let padding: CGFloat
    private let content: Content

    public init(
        title: String? = nil,
        icon: String? = nil,
        accent: Color = .paktPrimary,
        padding: CGFloat = PaktSpace.s4,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Leading accent bar — gives each surface a visible identity.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)

            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                if title != nil || icon != nil {
                    header
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
        }
        .background(
            RoundedRectangle(cornerRadius: PaktRadius.xxl, style: .continuous)
                .fill(Color.paktCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.xxl, style: .continuous)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PaktRadius.xxl, style: .continuous))
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(paktIcon: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
            }
            if let title {
                Text(title.uppercased())
                    .font(.pakt(.small))
                    .tracking(1.0)
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
    }
}
