import SwiftData
import SwiftUI

struct SearchView: View {
    let move: Move

    @State private var query: String = ""
    @State private var activeFilter: Disposition? = nil
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.top, PaktSpace.s2)

                filterBar
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.vertical, PaktSpace.s2)

                if results.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(results, id: \.id) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ResultRow(item: item)
                            }
                            .listRowBackground(Color.paktCard)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { searchFocused = true }
    }

    // MARK: - Components

    private var searchBar: some View {
        HStack(spacing: PaktSpace.s2) {
            Image(paktIcon: "search").foregroundStyle(Color.paktMutedForeground)
            TextField("Search items, notes, rooms…", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .foregroundStyle(Color.paktForeground)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(paktIcon: "x").foregroundStyle(Color.paktMutedForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PaktSpace.s3)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: PaktRadius.lg).fill(Color.paktMuted))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", isActive: activeFilter == nil) {
                    activeFilter = nil
                }
                ForEach(Disposition.allCases, id: \.self) { d in
                    FilterChip(
                        label: label(for: d),
                        isActive: activeFilter == d,
                        tint: tint(for: d)
                    ) {
                        activeFilter = activeFilter == d ? nil : d
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: PaktSpace.s2) {
            Spacer()
            Image(paktIcon: "search")
                .font(.system(size: 40))
                .foregroundStyle(Color.paktMutedForeground)
            Text(query.isEmpty ? "Start typing to search" : "No matches")
                .font(.pakt(.heading))
                .foregroundStyle(Color.paktForeground)
            if query.isEmpty {
                Text("Name, notes, category, and room are all searched.")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaktSpace.s6)
            }
            Spacer()
        }
    }

    // MARK: - Data

    private var allItems: [Item] {
        (move.items ?? []).filter { $0.deletedAt == nil }
    }

    private var results: [Item] {
        let base = allItems.filter { activeFilter == nil || $0.disposition == activeFilter }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else {
            return activeFilter == nil ? [] : base.sorted { $0.updatedAt > $1.updatedAt }
        }
        return base.filter { match($0, q) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func match(_ item: Item, _ q: String) -> Bool {
        if item.name.lowercased().contains(q) { return true }
        if let notes = item.notes, notes.lowercased().contains(q) { return true }
        if let cat = ItemCategories.lookup(item.categoryId),
           cat.label.lowercased().contains(q) { return true }
        if let room = item.sourceRoom, room.label.lowercased().contains(q) { return true }
        if let room = item.destinationRoom, room.label.lowercased().contains(q) { return true }
        return false
    }

    private func label(for d: Disposition) -> String {
        switch d {
        case .undecided: return "Undecided"
        case .moving:    return "Moving"
        case .storage:   return "Storage"
        case .donate:    return "Donate"
        case .trash:     return "Trash"
        case .sold:      return "Sold"
        }
    }

    private func tint(for d: Disposition) -> Color {
        switch d {
        case .moving:    return Color.paktMoving
        case .storage:   return Color.paktStorage
        case .donate:    return Color.paktDonate
        case .trash:     return Color.paktDestructive
        case .sold:      return Color.paktSold
        case .undecided: return Color.paktUndecided
        }
    }
}

// MARK: - Pieces

private struct FilterChip: View {
    let label: String
    var isActive: Bool
    var tint: Color = .paktPrimary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.pakt(.small))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isActive ? .white : Color.paktForeground)
                .background(Capsule().fill(isActive ? tint : Color.paktCard))
                .overlay(Capsule().strokeBorder(isActive ? tint : Color.paktBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ResultRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            Thumbnail(photo: item.photos?.first)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
                HStack(spacing: 6) {
                    if let room = item.sourceRoom {
                        Text(room.label).font(.pakt(.small))
                    }
                    if let cat = ItemCategories.lookup(item.categoryId) {
                        Text("·").foregroundStyle(Color.paktMutedForeground)
                        Text(cat.label).font(.pakt(.small))
                    }
                    if let boxShort = currentBoxShortCode {
                        Text("·").foregroundStyle(Color.paktMutedForeground)
                        Text(boxShort).font(.pakt(.mono).monospaced())
                    }
                }
                .foregroundStyle(Color.paktMutedForeground)
                .lineLimit(1)
            }

            Spacer()

            DispositionChip(disposition: item.disposition.rawValue)
        }
        .padding(.vertical, 2)
    }

    /// Derives the box this item currently lives in (if any) via the BoxItem
    /// relationship — handy to surface in search hits during packing.
    private var currentBoxShortCode: String? {
        (item.boxItems ?? []).lazy
            .compactMap { $0.box }
            .first { $0.deletedAt == nil }
            .map(\.shortCode)
    }
}

private struct Thumbnail: View {
    let photo: ItemPhoto?
    var body: some View {
        Group {
            if let data = photo?.data, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: PaktRadius.md).fill(Color.paktMuted)
                    .overlay(Image(paktIcon: "image")
                        .foregroundStyle(Color.paktMutedForeground))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: PaktRadius.md))
    }
}
