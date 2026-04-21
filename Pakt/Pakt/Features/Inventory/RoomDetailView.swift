import SwiftData
import SwiftUI
import TipKit

struct RoomDetailView: View {
    let room: Room

    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var showingAddChild = false
    private let swipeTip = SwipeToDeleteItemTip()

    @State private var confirmRemove = false

    var body: some View {
        List {
            if !childRooms.isEmpty {
                Section("Sub-rooms") {
                    ForEach(childRooms, id: \.id) { child in
                        NavigationLink {
                            RoomDetailView(room: child)
                        } label: {
                            HStack {
                                Image(paktIcon: "package-open")
                                    .foregroundStyle(Color.paktMutedForeground)
                                Text(child.label).font(.pakt(.body))
                                Spacer()
                                Text("\(itemCount(for: child))")
                                    .font(.pakt(.small))
                                    .foregroundStyle(Color.paktMutedForeground)
                            }
                        }
                        .listRowBackground(Color.paktCard)
                    }
                }
            }

            Section(items.isEmpty ? "" : "Items") {
                if !items.isEmpty, #available(iOS 17.0, *) {
                    TipView(swipeTip)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(items, id: \.id) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        ItemRow(item: item)
                    }
                    .listRowBackground(Color.paktCard)
                }
                .onDelete(perform: softDelete)
            }

            Section {
                Button(role: .destructive) {
                    confirmRemove = true
                } label: {
                    Label("Remove room", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.paktBackground)
        .navigationTitle(room.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAdd = true
                    } label: { Label("Add item", systemImage: "plus") }
                    Button {
                        showingAddChild = true
                    } label: { Label("Add sub-room", systemImage: "folder.badge.plus") }
                } label: {
                    Image(paktIcon: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddItemSheet(move: room.move, sourceRoom: room)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingAddChild) {
            AddRoomSheet(move: room.move, side: room.kind, parent: room)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Remove this room?",
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { removeRoom() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items in this room stay in your inventory and become unassigned. Sub-rooms become top-level. You can undo right after.")
        }
    }

    private func removeRoom() {
        for child in childRooms {
            child.parentRoom = nil
            child.updatedAt = Date()
        }
        room.deletedAt = Date()
        room.updatedAt = Date()
        try? context.save()
        let label = room.label
        let removed = room
        UndoToastCenter.shared.show(message: "\"\(label)\" removed") {
            removed.deletedAt = nil
            removed.updatedAt = Date()
            try? context.save()
        }
    }

    private var items: [Item] {
        (room.move?.items ?? [])
            .filter { $0.sourceRoom?.id == room.id && $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var childRooms: [Room] {
        (room.childRooms ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func itemCount(for child: Room) -> Int {
        (child.move?.items ?? [])
            .filter { $0.sourceRoom?.id == child.id && $0.deletedAt == nil }
            .count
    }

    private func softDelete(at offsets: IndexSet) {
        let now = Date()
        let removed = offsets.map { items[$0] }
        for item in removed {
            item.deletedAt = now
            item.updatedAt = now
        }
        try? context.save()
        DeletionTipEvents.userDidSwipeToDelete()

        let message = removed.count == 1
            ? "\(removed[0].name) removed"
            : "\(removed.count) items removed"
        UndoToastCenter.shared.show(message: message) {
            for item in removed {
                item.deletedAt = nil
                item.updatedAt = Date()
            }
            try? context.save()
        }
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            ThumbnailView(photo: item.photos?.first)

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
                    if let cat = ItemCategories.lookup(item.categoryId) {
                        Text(cat.label).font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                    if item.fragility != .normal {
                        PaktBadge(item.fragility == .veryFragile ? "Very fragile" : "Fragile",
                                  tone: .destructive)
                    }
                }
            }

            Spacer()

            DispositionChip(disposition: item.disposition.rawValue)
        }
        .padding(.vertical, 2)
    }
}

private struct ThumbnailView: View {
    let photo: ItemPhoto?

    var body: some View {
        Group {
            if let data = photo?.data, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: PaktRadius.md).fill(Color.paktMuted)
                    .overlay(Image(paktIcon: "image").foregroundStyle(Color.paktMutedForeground))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: PaktRadius.md))
    }
}
