import SwiftData
import SwiftUI

struct NewBoxSheet: View {
    let move: Move

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var boxTypeId: String = ""
    @State private var sourceRoomId: String = ""
    @State private var destinationRoomId: String = ""
    @State private var selectedTags: Set<BoxTag> = []
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Box type", selection: $boxTypeId) {
                        Text("Pick a type").tag("")
                        ForEach(availableBoxTypes, id: \.id) { type in
                            Text(type.label).tag(type.id)
                        }
                    }
                    if let type = selectedType {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text(volumeLabel(type))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Rooms") {
                    Picker("Source", selection: $sourceRoomId) {
                        Text("Any / unassigned").tag("")
                        ForEach(originRooms, id: \.id) { r in
                            Text(fullLabel(r)).tag(r.id)
                        }
                    }
                    Picker("Destination", selection: $destinationRoomId) {
                        Text("Any / unassigned").tag("")
                        ForEach(destinationRooms, id: \.id) { r in
                            Text(fullLabel(r)).tag(r.id)
                        }
                    }
                }

                Section("Tags") {
                    ForEach(BoxTag.allCases, id: \.self) { tag in
                        Toggle(tag.label, isOn: Binding(
                            get: { selectedTags.contains(tag) },
                            set: { on in
                                if on { selectedTags.insert(tag) } else { selectedTags.remove(tag) }
                            }
                        ))
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paktBackground)
            .navigationTitle("New box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create", action: submit)
                        .disabled(!canSubmit)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if boxTypeId.isEmpty, let first = availableBoxTypes.first {
                    boxTypeId = first.id
                }
            }
        }
    }

    private var canSubmit: Bool { selectedType != nil }

    private var availableBoxTypes: [BoxType] {
        (move.boxTypes ?? []).filter { $0.deletedAt == nil }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private var selectedType: BoxType? {
        availableBoxTypes.first { $0.id == boxTypeId }
    }

    private var originRooms: [Room] {
        (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .origin }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private var destinationRooms: [Room] {
        (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .destination }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func fullLabel(_ r: Room) -> String {
        r.parentRoom.map { "\($0.label) › \(r.label)" } ?? r.label
    }

    private func volumeLabel(_ t: BoxType) -> String {
        guard let volume = t.volumeCuFt else { return "—" }
        return String(format: "%.2f cuft", volume)
    }

    private func submit() {
        guard let type = selectedType else { return }
        let source = originRooms.first { $0.id == sourceRoomId }
        let dest = destinationRooms.first { $0.id == destinationRoomId }
        let box = Box(
            move: move,
            boxType: type,
            sourceRoom: source,
            destinationRoom: dest,
            status: .empty,
            tags: Array(selectedTags)
        )
        box.notes = notes.isEmpty ? nil : notes
        context.insert(box)
        try? context.save()
        dismiss()
    }
}
