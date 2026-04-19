import SwiftData
import SwiftUI

struct BoxTypesView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing: BoxType?
    @State private var showingNew = false

    var body: some View {
        List {
            ForEach(visibleTypes, id: \.id) { type in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.label).font(.pakt(.body))
                        if let v = type.volumeCuFt {
                            Text(String(format: "%.2f cuft", v))
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                    }
                    Spacer()
                    Text("\(usageCount(type))")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                    Image(paktIcon: "chevron-right")
                        .foregroundStyle(Color.paktMutedForeground)
                }
                .contentShape(Rectangle())
                .onTapGesture { editing = type }
                .listRowBackground(Color.paktCard)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.paktBackground)
        .navigationTitle("Box types")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }.foregroundStyle(Color.paktMutedForeground)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(paktIcon: "plus") }
            }
        }
        .sheet(item: $editing) { t in
            EditBoxTypeSheet(boxType: t).presentationDetents([.medium])
        }
        .sheet(isPresented: $showingNew) {
            EditBoxTypeSheet(move: move).presentationDetents([.medium])
        }
    }

    // MARK: - Helpers

    private var visibleTypes: [BoxType] {
        (move.boxTypes ?? []).filter { $0.deletedAt == nil }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func usageCount(_ type: BoxType) -> Int {
        (move.boxes ?? []).filter { $0.boxType?.id == type.id && $0.deletedAt == nil }.count
    }

    private func delete(at offsets: IndexSet) {
        let types = visibleTypes
        for index in offsets {
            let t = types[index]
            if usageCount(t) > 0 {
                // Soft-delete only when unused.
                continue
            }
            t.deletedAt = Date()
            t.updatedAt = Date()
        }
        try? context.save()
    }
}

/// Sheet for both create (given a move) and edit (given a boxType).
struct EditBoxTypeSheet: View {
    let move: Move?
    let boxType: BoxType?

    init(move: Move) {
        self.move = move
        self.boxType = nil
        _label = State(initialValue: "")
        _volumeText = State(initialValue: "")
    }

    init(boxType: BoxType) {
        self.move = boxType.move
        self.boxType = boxType
        _label = State(initialValue: boxType.label)
        _volumeText = State(initialValue: boxType.volumeCuFt.map { String($0) } ?? "")
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var volumeText: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Medium, Dish pack…", text: $label)
                }
                Section("Volume (cuft, optional)") {
                    TextField("3.0", text: $volumeText)
                        .keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paktBackground)
            .navigationTitle(boxType == nil ? "New box type" : "Edit box type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.paktMutedForeground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: submit)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func submit() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let volume = Double(volumeText)
        if let t = boxType {
            t.label = trimmed
            t.volumeCuFt = volume
            t.updatedAt = Date()
        } else if let move {
            let existingCount = (move.boxTypes ?? []).count
            let t = BoxType(move: move, label: trimmed, volumeCuFt: volume,
                            sortOrder: (existingCount + 1) * 10)
            context.insert(t)
        }
        try? context.save()
        dismiss()
    }
}
