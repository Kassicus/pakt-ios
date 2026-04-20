import SwiftData
import SwiftUI

struct AddItemSheet: View {
    let move: Move?
    let sourceRoom: Room?
    var onCreate: ((Item) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var quantity = 1
    @State private var categoryId: String = ItemCategories.defaultCategoryId
    @State private var disposition: Disposition = .undecided
    @State private var fragility: Fragility = .normal
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                }

                Section("Category") {
                    Picker("Category", selection: $categoryId) {
                        ForEach(ItemCategories.all) { cat in
                            Text(cat.label).tag(cat.id)
                        }
                    }
                    if let cat = ItemCategories.lookup(categoryId) {
                        HStack {
                            Text("Typical volume")
                            Spacer()
                            Text("\(cat.volumeCuFtPerItem, specifier: "%.2f") cuft")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Typical weight")
                            Spacer()
                            Text("\(cat.weightLbsPerItem, specifier: "%.1f") lbs")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Triage") {
                    Picker("Disposition", selection: $disposition) {
                        ForEach(Disposition.allCases, id: \.self) { d in
                            Text(label(for: d)).tag(d)
                        }
                    }
                    Picker("Fragility", selection: $fragility) {
                        Text("Normal").tag(Fragility.normal)
                        Text("Fragile").tag(Fragility.fragile)
                        Text("Very fragile").tag(Fragility.veryFragile)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paktBackground)
            .navigationTitle("Add item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", action: submit)
                        .disabled(!canSubmit)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let room = sourceRoom, let cat = defaultCategory(for: room) {
                    categoryId = cat.id
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let item = Item(
            move: move,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceRoom: sourceRoom,
            categoryId: categoryId,
            quantity: quantity,
            disposition: disposition,
            fragility: effectiveFragility
        )
        item.notes = notes.isEmpty ? nil : notes
        context.insert(item)
        try? context.save()
        onCreate?(item)
        dismiss()
    }

    /// If the user hasn't chosen, bump fragility to `.fragile` when the category is fragile.
    private var effectiveFragility: Fragility {
        if fragility == .normal, let cat = ItemCategories.lookup(categoryId), cat.fragile {
            return .fragile
        }
        return fragility
    }

    private func defaultCategory(for room: Room) -> ItemCategory? {
        let label = room.label.lowercased()
        if label.contains("kitchen")  { return ItemCategories.byId["cat_kitchen_dishes"] }
        if label.contains("closet")   { return ItemCategories.byId["cat_clothes_folded"] }
        if label.contains("bedroom")  { return ItemCategories.byId["cat_clothes_folded"] }
        if label.contains("office")   { return ItemCategories.byId["cat_documents_files"] }
        if label.contains("living")   { return ItemCategories.byId["cat_decor_small"] }
        if label.contains("bath")     { return ItemCategories.byId["cat_towels"] }
        return nil
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
}
