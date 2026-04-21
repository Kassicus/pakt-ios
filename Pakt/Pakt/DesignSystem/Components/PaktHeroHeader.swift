import SwiftUI

/// Full-bleed hero header — replaces `navigationTitle` as the primary identity of a screen.
/// Eyebrow is the feature tag (small tracked uppercase accent), title is the main label,
/// subtitle is muted supporting text, and the trailing slot hosts a badge / avatar / stat.
public struct PaktHeroHeader<Trailing: View>: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let accent: Color
    private let titleStyle: PaktFont
    private let trailing: Trailing

    public init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        accent: Color = .paktPrimary,
        titleStyle: PaktFont = .title,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.titleStyle = titleStyle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: PaktSpace.s3) {
            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 14, height: 2)
                            .clipShape(Capsule())
                        Text(eyebrow.uppercased())
                            .font(.pakt(.small))
                            .tracking(1.2)
                            .foregroundStyle(accent)
                    }
                }
                Text(title)
                    .font(.pakt(titleStyle))
                    .foregroundStyle(Color.paktForeground)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

public extension PaktHeroHeader where Trailing == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        accent: Color = .paktPrimary,
        titleStyle: PaktFont = .title
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            accent: accent,
            titleStyle: titleStyle,
            trailing: { EmptyView() }
        )
    }
}
