import SwiftData
import SwiftUI

struct RoomListView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @State private var side: RoomKind = .origin
    @State private var showingAddRoom = false
    @State private var mirrorConfirmation = false

    var body: some View {
        PaktScreen(accent: sideAccent) {
            PaktHeroHeader(
                eyebrow: "Inventory",
                title: "Rooms",
                subtitle: subtitle,
                accent: sideAccent,
                titleStyle: .title
            ) {
                Text("\(topLevelRooms(for: side).count)")
                    .font(.pakt(.hero))
                    .foregroundStyle(sideAccent)
                    .contentTransition(.numericText(value: Double(topLevelRooms(for: side).count)))
                    .animation(PaktMotion.standard, value: topLevelRooms(for: side).count)
            }

            PaktTabs(selection: $side, options: [
                .init(value: .origin, label: "Origin"),
                .init(value: .destination, label: "Destination"),
            ])

            if side == .destination, topLevelRooms(for: .destination).isEmpty,
               !topLevelRooms(for: .origin).isEmpty {
                PaktSurface(title: "Shortcut", icon: "sparkles", accent: .paktAccent) {
                    VStack(alignment: .leading, spacing: PaktSpace.s2) {
                        Text("Mirror your origin rooms")
                            .font(.pakt(.heading))
                            .foregroundStyle(Color.paktForeground)
                        Text("Copy every origin room to the destination side so you have somewhere to send each item.")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                        PaktButton("Mirror rooms") { mirrorConfirmation = true }
                            .padding(.top, 4)
                    }
                }
            }

            if topLevelRooms(for: side).isEmpty {
                PaktEmptyState(
                    icon: "home",
                    title: side == .origin ? "Add your origin rooms" : "Add destination rooms",
                    message: "Group your items by where they live today and where they'll go next.",
                    accent: sideAccent,
                    primary: .init("Add a room") { showingAddRoom = true }
                )
            } else {
                VStack(spacing: PaktSpace.s2) {
                    ForEach(topLevelRooms(for: side), id: \.id) { room in
                        RoomRow(room: room, depth: 0)
                    }
                }
            }
        }
        .navigationTitle("")
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

    private var sideAccent: Color {
        side == .origin ? .paktMoving : .paktStorage
    }

    private var subtitle: String {
        let count = topLevelRooms(for: side).count
        let noun = count == 1 ? "room" : "rooms"
        let label = side == .origin ? "origin" : "destination"
        return count == 0 ? "No \(label) rooms yet" : "\(count) \(label) \(noun)"
    }

    private func topLevelRooms(for side: RoomKind) -> [Room] {
        (move.rooms ?? [])
            .filter { $0.deletedAt == nil && $0.kind == side && $0.parentRoom == nil }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func mirror() {
        let existingDestLabels = Set(
            (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .destination }.map(\.label)
        )
        let originRooms = (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .origin }
        var idMap: [String: Room] = [:]
        for origin in originRooms where origin.parentRoom == nil {
            guard !existingDestLabels.contains(origin.label) else { continue }
            let copy = Room(move: move, kind: .destination,
                            label: origin.label, sortOrder: origin.sortOrder)
            context.insert(copy)
            idMap[origin.id] = copy
        }
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

    private var rowAccent: Color {
        if depth > 0 { return .paktMutedForeground }
        return room.kind == .origin ? .paktMoving : .paktStorage
    }

    var body: some View {
        VStack(spacing: 4) {
            PaktSurface(accent: rowAccent, padding: PaktSpace.s3) {
                HStack(spacing: PaktSpace.s2) {
                    NavigationLink { RoomDetailView(room: room) } label: {
                        HStack(spacing: PaktSpace.s3) {
                            Image(paktIcon: depth > 0 ? "package-open" : "home")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(rowAccent)
                                .background(
                                    RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                                        .fill(rowAccent.opacity(0.14))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.label)
                                    .font(depth > 0 ? .pakt(.body) : .pakt(.bodyMedium))
                                    .foregroundStyle(Color.paktForeground)
                                Text(itemCountLabel)
                                    .font(.pakt(.small))
                                    .foregroundStyle(Color.paktMutedForeground)
                            }

                            Spacer()

                            Image(paktIcon: "chevron-right")
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button { showingAddChild = true } label: {
                            Label("Add sub-room", systemImage: "plus")
                        }
                        Button { showingEdit = true } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) { delete() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(paktIcon: "more-vertical")
                            .foregroundStyle(Color.paktMutedForeground)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, depth > 0 ? CGFloat(depth) * 16 : 0)
            .contextMenu {
                Button { showingAddChild = true } label: {
                    Label("Add sub-room", systemImage: "plus")
                }
                Button { showingEdit = true } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) { delete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            ForEach(children, id: \.id) { child in
                RoomRow(room: child, depth: depth + 1)
            }
        }
        .sheet(isPresented: $showingEdit) {
            RenameRoomSheet(room: room).presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showingAddChild) {
            AddRoomSheet(move: room.move, side: room.kind, parent: room).presentationDetents([.medium])
        }
    }

    private var children: [Room] {
        (room.childRooms ?? [])
            .filter { $0.deletedAt == nil }
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
        for child in children {
            child.parentRoom = nil
            child.updatedAt = Date()
        }
        room.deletedAt = Date()
        room.updatedAt = Date()
        try? context.save()
        UndoToastCenter.shared.show(message: "\"\(room.label)\" removed") {
            room.deletedAt = nil
            room.updatedAt = Date()
            try? context.save()
        }
    }
}
