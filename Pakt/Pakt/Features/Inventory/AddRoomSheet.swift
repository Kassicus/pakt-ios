import SwiftData
import SwiftUI

struct AddRoomSheet: View {
    let move: Move?
    let side: RoomKind
    let parent: Room?

    init(move: Move?, side: RoomKind, parent: Room? = nil) {
        self.move = move
        self.side = side
        self.parent = parent
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: PaktSpace.s4) {
                    Text(parent == nil
                         ? (side == .origin ? "New origin room" : "New destination room")
                         : "New closet in \(parent?.label ?? "")")
                        .font(.pakt(.heading))
                        .foregroundStyle(Color.paktForeground)

                    PaktTextField("Kitchen, Primary bedroom…", text: $label)

                    Spacer()

                    PaktButton("Add", size: .lg, action: submit)
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(label.isEmpty ? 0.6 : 1)
                }
                .padding(PaktSpace.s4)
            }
            .navigationTitle("Add room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
    }

    private func submit() {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let existingCount = (move?.rooms ?? []).filter { $0.kind == side }.count
        let room = Room(move: move, kind: side, label: trimmed,
                        parentRoom: parent, sortOrder: existingCount * 10)
        context.insert(room)
        try? context.save()
        dismiss()
    }
}

struct RenameRoomSheet: View {
    let room: Room

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var label: String

    init(room: Room) {
        self.room = room
        _label = State(initialValue: room.label)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: PaktSpace.s4) {
                    Text("Rename room").font(.pakt(.heading))
                        .foregroundStyle(Color.paktForeground)
                    PaktTextField("Name", text: $label)
                    Spacer()
                    PaktButton("Save", size: .lg, action: submit)
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(PaktSpace.s4)
            }
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
    }

    private func submit() {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        room.label = trimmed
        room.updatedAt = Date()
        try? context.save()
        dismiss()
    }
}
