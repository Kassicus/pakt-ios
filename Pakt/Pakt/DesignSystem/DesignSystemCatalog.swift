import SwiftUI

/// Debug screen exercising every design-system component in both schemes.
/// Added to M0's "done when": render and snapshot-test this view.
public struct DesignSystemCatalog: View {
    @State private var segment: String = "origin"
    @State private var tab: String = "inventory"
    @State private var text: String = ""
    @State private var secret: String = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s6) {
                section("Typography") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title — 24/semibold").font(.pakt(.title))
                        Text("Heading — 18/medium").font(.pakt(.heading))
                        Text("Body — 14/regular").font(.pakt(.body))
                        Text("Small — 12/medium").font(.pakt(.small)).foregroundStyle(.secondary)
                        Text("Mono — 14").font(.pakt(.mono))
                    }
                }

                section("Buttons — variants") {
                    VStack(alignment: .leading, spacing: PaktSpace.s2) {
                        PaktButton("Default",     variant: .default)     { }
                        PaktButton("Outline",     variant: .outline)     { }
                        PaktButton("Secondary",   variant: .secondary)   { }
                        PaktButton("Ghost",       variant: .ghost)       { }
                        PaktButton("Destructive", variant: .destructive) { }
                        PaktButton("Link",        variant: .link)        { }
                    }
                }

                section("Buttons — sizes") {
                    HStack(spacing: PaktSpace.s2) {
                        PaktButton("xs",      size: .xs)      { }
                        PaktButton("sm",      size: .sm)      { }
                        PaktButton("default", size: .default) { }
                        PaktButton("lg",      size: .lg)      { }
                    }
                }

                section("Badges") {
                    HStack(spacing: PaktSpace.s2) {
                        PaktBadge("Default")
                        PaktBadge("Secondary",   tone: .secondary)
                        PaktBadge("Destructive", tone: .destructive)
                        PaktBadge("Outline",     tone: .outline)
                        PaktBadge("Ghost",       tone: .ghost)
                    }
                }

                section("Disposition chips") {
                    HStack(spacing: PaktSpace.s2) {
                        DispositionChip(disposition: "moving")
                        DispositionChip(disposition: "storage")
                        DispositionChip(disposition: "donate")
                        DispositionChip(disposition: "trash")
                        DispositionChip(disposition: "undecided")
                    }
                }

                section("Card + text field") {
                    PaktCard {
                        VStack(alignment: .leading, spacing: PaktSpace.s3) {
                            Text("Card title").font(.pakt(.heading))
                            PaktTextField("Room name", text: $text)
                            PaktTextField("Password",  text: $secret, isSecure: true)
                        }
                    }
                }

                section("Tabs (pill)") {
                    PaktTabs(selection: $segment, options: [
                        .init(value: "origin", label: "Origin"),
                        .init(value: "destination", label: "Destination"),
                    ])
                }

                section("Icons") {
                    HStack(spacing: 16) {
                        ForEach(["package-open","shuffle","search","box","scan-line","camera","trash","plus"], id: \.self) { name in
                            Image(paktIcon: name).font(.system(size: 20))
                        }
                    }
                    .foregroundStyle(Color.paktForeground)
                }

                section("Section headers (in Form)") {
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
                    .scrollContentBackground(.hidden)
                    .frame(height: 280)
                }

                section("Box status track") {
                    VStack(alignment: .leading, spacing: PaktSpace.s3) {
                        ForEach(BoxStatus.ordered, id: \.self) { status in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(status.label).font(.pakt(.small))
                                    .foregroundStyle(Color.paktMutedForeground)
                                BoxStatusTrack(current: status)
                            }
                        }
                    }
                }

                section("Empty state") {
                    PaktEmptyState(
                        icon: "package-open",
                        title: "Start your first move",
                        message: "Track inventory, box contents, and everything else from here.",
                        primary: .init("Create a move") {},
                        secondary: .init("Accept an invite") {}
                    )
                }

                Spacer(minLength: 80)
            }
            .padding(PaktSpace.s4)
        }
        .safeAreaInset(edge: .bottom) {
            BottomTabBar(selection: $tab).onTapGesture {}
        }
        .background(Color.paktBackground)
    }

    @ViewBuilder
    private func section<V: View>(_ title: String, @ViewBuilder _ body: () -> V) -> some View {
        VStack(alignment: .leading, spacing: PaktSpace.s2) {
            Text(title).font(.pakt(.small)).foregroundStyle(Color.paktMutedForeground).textCase(.uppercase)
            body()
        }
    }
}

#Preview("Dark") {
    DesignSystemCatalog().preferredColorScheme(.dark)
}

#Preview("Light") {
    DesignSystemCatalog().preferredColorScheme(.light)
}
