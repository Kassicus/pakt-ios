import SwiftData
import SwiftUI

struct RoomListView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @State private var side: RoomKind = .origin
    @State private var showingAddRoom = false
    @State private var mirrorConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s4) {
                PaktTabs(selection: $side, options: [
                    .init(value: .origin, label: "Origin"),
                    .init(value: .destination, label: "Destination"),
                ])

                if side == .destination, topLevelRooms(for: .destination).isEmpty,
                   !topLevelRooms(for: .origin).isEmpty {
                    PaktCard {
                        VStack(alignment: .leading, spacing: PaktSpace.s2) {
                            Text("Mirror your origin rooms").font(.pakt(.heading))
                                .foregroundStyle(Color.paktForeground)
                            Text("Copy every origin room to the destination side so you have somewhere to send each item.")
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                            PaktButton("Mirror rooms") { mirrorConfirmation = true }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(topLevelRooms(for: side), id: \.id) { room in
                        RoomRow(room: room, depth: 0)
                    }
                }

                if topLevelRooms(for: side).isEmpty {
                    EmptyRoomsView(side: side) { showingAddRoom = true }
                }

                Spacer(minLength: 40)
            }
            .padding(PaktSpace.s4)
        }
        .background(Color.paktBackground)
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddRoom = true } label: { Image(paktIcon: "plus") }
            }
        }
        .sheet(isPresented: $showingAddRoom) {
            AddRoomSheet(move: move, side: side)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Mirror origin rooms to destination?",
            isPresented: $mirrorConfirmation,
            titleVisibility: .visible
        ) {
            Button("Mirror rooms", role: .none) { mirror() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll copy every origin room (and its closets) to the destination side. Nothing already on the destination side is touched.")
        }
    }

    private func topLevelRooms(for side: RoomKind) -> [Room] {
        (move.rooms ?? [])
            .filter { $0.kind == side && $0.parentRoom == nil }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func mirror() {
        let existingDestLabels = Set(
            (move.rooms ?? []).filter { $0.kind == .destination }.map(\.label)
        )
        let originRooms = (move.rooms ?? []).filter { $0.kind == .origin }
        // 1st pass — top-level rooms; remember originId → new destination room for closet mapping.
        var idMap: [String: Room] = [:]
        for origin in originRooms where origin.parentRoom == nil {
            guard !existingDestLabels.contains(origin.label) else { continue }
            let copy = Room(move: move, kind: .destination,
                            label: origin.label, sortOrder: origin.sortOrder)
            context.insert(copy)
            idMap[origin.id] = copy
        }
        // 2nd pass — closets under those rooms.
        for origin in originRooms where origin.parentRoom != nil {
            guard let parent = origin.parentRoom,
                  let newParent = idMap[parent.id] else { continue }
            let copy = Room(move: move, kind: .destination,
                            label: origin.label, parentRoom: newParent,
                            sortOrder: origin.sortOrder)
            context.insert(copy)
        }
        try? context.save()
        side = .destination
    }
}

// MARK: - Row

private struct RoomRow: View {
    let room: Room
    let depth: Int

    @Environment(\.modelContext) private var context
    @State private var showingEdit = false
    @State private var showingAddChild = false

    var body: some View {
        VStack(spacing: 4) {
            NavigationLink(value: room) {
                HStack(spacing: PaktSpace.s2) {
                    if depth > 0 {
                        Rectangle().fill(Color.paktBorder).frame(width: 2).padding(.leading, 6)
                    }
                    Image(paktIcon: depth > 0 ? "package-open" : "home")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(Color.paktMutedForeground)
                        .background(RoundedRectangle(cornerRadius: PaktRadius.md).fill(Color.paktMuted))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.label).font(depth > 0 ? .pakt(.body) : .pakt(.bodyMedium))
                            .foregroundStyle(Color.paktForeground)
                        Text(itemCountLabel)
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }

                    Spacer()

                    Menu {
                        Button("Add closet") { showingAddChild = true }
                        Button("Rename") { showingEdit = true }
                        Divider()
                        Button("Delete", role: .destructive) { delete() }
                    } label: {
                        Image(paktIcon: "more-vertical").foregroundStyle(Color.paktMutedForeground)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)

                    Image(paktIcon: "chevron-right")
                        .foregroundStyle(Color.paktMutedForeground)
                }
                .padding(PaktSpace.s3)
                .background(RoundedRectangle(cornerRadius: PaktRadius.lg).fill(Color.paktCard))
                .overlay(RoundedRectangle(cornerRadius: PaktRadius.lg).strokeBorder(Color.paktBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.leading, depth > 0 ? CGFloat(depth) * 16 : 0)

            ForEach(children, id: \.id) { child in
                RoomRow(room: child, depth: depth + 1)
            }
        }
        .sheet(isPresented: $showingEdit) { RenameRoomSheet(room: room).presentationDetents([.height(200)]) }
        .sheet(isPresented: $showingAddChild) {
            AddRoomSheet(move: room.move, side: room.kind, parent: room).presentationDetents([.medium])
        }
    }

    private var children: [Room] {
        (room.childRooms ?? [])
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private var itemCountLabel: String {
        let count = (room.move?.items ?? [])
            .filter { $0.sourceRoom?.id == room.id && $0.deletedAt == nil }
            .count
        if count == 0 { return "No items yet" }
        return "\(count) item\(count == 1 ? "" : "s")"
    }

    private func delete() {
        // Children become top-level rooms of the same side (matches the web).
        for child in children {
            child.parentRoom = nil
            child.updatedAt = Date()
        }
        context.delete(room)
        try? context.save()
    }
}

// MARK: - Empty state

private struct EmptyRoomsView: View {
    let side: RoomKind
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: PaktSpace.s3) {
            Image(paktIcon: "home")
                .font(.system(size: 36))
                .foregroundStyle(Color.paktMutedForeground)
            Text(side == .origin ? "Add your origin rooms" : "Add destination rooms")
                .font(.pakt(.heading))
            Text("Group your items by where they live today and where they'll go next.")
                .multilineTextAlignment(.center)
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
            PaktButton("Add a room", action: onAdd)
        }
        .frame(maxWidth: .infinity)
        .padding(PaktSpace.s6)
    }
}
