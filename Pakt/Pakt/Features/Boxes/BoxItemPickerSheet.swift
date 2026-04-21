import SwiftData
import SwiftUI

struct BoxItemPickerSheet: View {
    let box: Box

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var query: String = ""
    @State private var selectedIds: Set<String> = []
    @State private var showingNewItem = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, PaktSpace.s4)
                        .padding(.top, PaktSpace.s2)
                    List {
                        ForEach(groupedItems, id: \.roomName) { group in
                            Section(group.roomName) {
                                ForEach(group.items, id: \.id) { item in
                                    row(for: item)
                                        .listRowBackground(Color.paktCard)
                                        .contentShape(Rectangle())
                                        .onTapGesture { toggle(item) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedIds.isEmpty {
                        Button {
                            showingNewItem = true
                        } label: {
                            Label("New", systemImage: "plus")
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Add (\(selectedIds.count))") { attachSelected() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingNewItem) {
                AddItemSheet(
                    move: box.move,
                    sourceRoom: box.sourceRoom,
                    destinationRoom: box.destinationRoom,
                    onCreate: attachCreated
                )
                .presentationDetents([.large])
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: PaktSpace.s2) {
            Image(paktIcon: "search").foregroundStyle(Color.paktMutedForeground)
            TextField("Search items", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.paktForeground)
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

    // MARK: - Selection

    private func toggle(_ item: Item) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
    }

    private func attachCreated(_ item: Item) {
        let bi = BoxItem(box: box, item: item, quantity: item.quantity)
        context.insert(bi)
        box.updatedAt = Date()
        if box.status == .empty { box.status = .packing }
        try? context.save()
    }

    private func attachSelected() {
        let already = Set((box.boxItems ?? []).compactMap { $0.item?.id })
        let candidates = candidateItems.filter { selectedIds.contains($0.id) && !already.contains($0.id) }
        for item in candidates {
            let bi = BoxItem(box: box, item: item, quantity: item.quantity)
            context.insert(bi)
        }
        box.updatedAt = Date()
        if box.status == .empty { box.status = .packing }
        try? context.save()
        dismiss()
    }

    // MARK: - Data

    private var candidateItems: [Item] {
        let already = Set((box.boxItems ?? []).compactMap { $0.item?.id })
        return (box.move?.items ?? [])
            .filter { $0.deletedAt == nil && !already.contains($0.id) }
    }

    private var filteredItems: [Item] {
        let base = candidateItems
        guard !query.isEmpty else { return base }
        let q = query.lowercased()
        return base.filter { item in
            item.name.lowercased().contains(q)
                || (item.notes?.lowercased().contains(q) ?? false)
                || (ItemCategories.lookup(item.categoryId)?.label.lowercased().contains(q) ?? false)
                || (item.sourceRoom?.label.lowercased().contains(q) ?? false)
        }
    }

    private struct RoomGroup {
        let roomName: String
        let items: [Item]
    }

    private var groupedItems: [RoomGroup] {
        let dict = Dictionary(grouping: filteredItems) { item -> String in
            item.sourceRoom?.label ?? "Unassigned"
        }
        return dict
            .map { RoomGroup(roomName: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.roomName < $1.roomName }
    }

    @ViewBuilder private func row(for item: Item) -> some View {
        let selected = selectedIds.contains(item.id)
        HStack(spacing: PaktSpace.s3) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? Color.paktPrimary : Color.paktMutedForeground)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.pakt(.bodyMedium))
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
                if let cat = ItemCategories.lookup(item.categoryId) {
                    Text(cat.label)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
            Spacer()
            DispositionChip(disposition: item.disposition.rawValue)
        }
    }
}
