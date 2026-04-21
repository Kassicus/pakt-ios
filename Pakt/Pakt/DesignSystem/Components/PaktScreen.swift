import SwiftUI

/// Full-bleed screen wrapper with a tinted gradient backdrop anchored to an accent color.
/// Replaces the flat `.paktBackground` fill + ScrollView pattern that looks like iOS defaults.
public struct PaktScreen<Content: View>: View {
    private let accent: Color
    private let content: Content
    private let topPadding: CGFloat
    private let bottomPadding: CGFloat

    public init(
        accent: Color = .paktPrimary,
        topPadding: CGFloat = PaktSpace.s3,
        bottomPadding: CGFloat = PaktSpace.s10,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            backdrop
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: PaktSpace.s4) {
                    content
                }
                .padding(.horizontal, PaktSpace.s4)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.paktBackground
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    accent.opacity(0.08),
                    Color.paktBackground.opacity(0),
                ],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.plusLighter)

            // Subtle off-center radial glow to fight the flat look
            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 10,
                endRadius: 260
            )
            .blendMode(.plusLighter)
        }
    }
}
