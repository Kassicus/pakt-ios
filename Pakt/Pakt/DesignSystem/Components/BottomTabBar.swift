import SwiftUI

public struct BottomTab: Identifiable, Hashable {
    public let id: String
    public let icon: String
    public let title: String

    public init(id: String, icon: String, title: String) {
        self.id = id
        self.icon = icon
        self.title = title
    }
}

/// The five-tab mobile nav from the web app — Inventory, Triage, Search, Boxes, Scan.
public struct BottomTabBar: View {
    public static let defaultTabs: [BottomTab] = [
        .init(id: "inventory", icon: "package-open", title: "Inventory"),
        .init(id: "triage",    icon: "shuffle",      title: "Triage"),
        .init(id: "search",    icon: "search",       title: "Search"),
        .init(id: "boxes",     icon: "box",          title: "Boxes"),
        .init(id: "scan",      icon: "scan-line",    title: "Scan"),
    ]

    public let tabs: [BottomTab]
    @Binding public var selection: String

    public init(tabs: [BottomTab] = BottomTabBar.defaultTabs, selection: Binding<String>) {
        self.tabs = tabs
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let active = tab.id == selection
                Button {
                    withAnimation(PaktMotion.quick) { selection = tab.id }
                } label: {
                    VStack(spacing: 2) {
                        Image(paktIcon: tab.icon)
                            .font(.system(size: 20, weight: active ? .semibold : .regular))
                        Text(tab.title).font(.pakt(.small))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .foregroundStyle(active ? Color.paktForeground : Color.paktMutedForeground)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 56)
        .padding(.bottom, 0)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color.paktBorder).frame(height: 0.5), alignment: .top)
    }
}
