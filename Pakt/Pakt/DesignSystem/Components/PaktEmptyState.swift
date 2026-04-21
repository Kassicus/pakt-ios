import SwiftUI

public struct PaktEmptyState: View {
    public struct Action {
        public let label: String
        public let perform: () -> Void
        public init(_ label: String, perform: @escaping () -> Void) {
            self.label = label
            self.perform = perform
        }
    }

    private let icon: String
    private let title: String
    private let message: String
    private let accent: Color
    private let primary: Action?
    private let secondary: Action?

    public init(
        icon: String,
        title: String,
        message: String,
        accent: Color = .paktPrimary,
        primary: Action? = nil,
        secondary: Action? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.accent = accent
        self.primary = primary
        self.secondary = secondary
    }

    @State private var appeared = false

    public var body: some View {
        PaktCard(padding: PaktSpace.s6) {
            VStack(spacing: PaktSpace.s3) {
                Image(paktIcon: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(accent.opacity(0.12)))
                Text(title)
                    .font(.pakt(.heading))
                    .foregroundStyle(Color.paktForeground)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaktSpace.s2)
                if let primary {
                    PaktButton(primary.label, size: .lg, action: primary.perform)
                        .padding(.top, PaktSpace.s1)
                }
                if let secondary {
                    PaktButton(secondary.label, variant: .ghost, action: secondary.perform)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(PaktMotion.sheet.delay(0.05)) { appeared = true }
        }
    }
}

#Preview("Empty state") {
    ScrollView {
        VStack(spacing: PaktSpace.s4) {
            PaktEmptyState(
                icon: "package-open",
                title: "Start your first move",
                message: "Track inventory, box contents, and everything else from here.",
                primary: .init("Create a move") {},
                secondary: .init("Accept an invite") {}
            )
            PaktEmptyState(
                icon: "home",
                title: "Add your origin rooms",
                message: "Group your items by where they live today and where they'll go next.",
                accent: .paktMoving,
                primary: .init("Add a room") {}
            )
        }
        .padding(PaktSpace.s4)
    }
    .background(Color.paktBackground)
}
