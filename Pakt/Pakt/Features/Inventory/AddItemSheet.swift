import SwiftData
import SwiftUI

struct AddItemSheet: View {
    let move: Move?
    let sourceRoom: Room?
    var destinationRoom: Room? = nil
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
                        ForEach(orderedCategories) { cat in
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
                if let inferred = inferredDisposition {
                    disposition = inferred
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
        relevantCategoryIds(for: room).first.flatMap { ItemCategories.byId[$0] }
    }

    private func relevantCategoryIds(for room: Room) -> [String] {
        let label = room.label.lowercased()
        if label.contains("kitchen") {
            return ["cat_kitchen_dishes", "cat_kitchen_cookware", "cat_kitchen_small_appliance", "cat_kitchen_pantry"]
        }
        if label.contains("dining") {
            return ["cat_kitchen_dishes", "cat_decor_small", "cat_furniture_medium"]
        }
        if label.contains("closet") {
            return ["cat_clothes_folded", "cat_clothes_hanging", "cat_shoes"]
        }
        if label.contains("bedroom") {
            return ["cat_clothes_folded", "cat_clothes_hanging", "cat_shoes", "cat_linens_bedding", "cat_decor_small", "cat_electronics_small", "cat_books"]
        }
        if label.contains("office") {
            return ["cat_documents_files", "cat_books", "cat_electronics_small", "cat_electronics_monitor", "cat_tools"]
        }
        if label.contains("living") || label.contains("family") || label.contains("den") {
            return ["cat_decor_small", "cat_decor_art_framed", "cat_electronics_small", "cat_electronics_monitor", "cat_books", "cat_furniture_small", "cat_furniture_medium"]
        }
        if label.contains("bath") {
            return ["cat_towels", "cat_linens_bedding"]
        }
        if label.contains("garage") || label.contains("shed") || label.contains("basement") {
            return ["cat_tools", "cat_furniture_small", "cat_furniture_medium"]
        }
        if label.contains("laundry") {
            return ["cat_linens_bedding", "cat_towels", "cat_clothes_folded"]
        }
        return []
    }

    /// Categories that are typical for the source room, followed by everything else.
    private var orderedCategories: [ItemCategory] {
        guard let room = sourceRoom else { return ItemCategories.all }
        let ids = relevantCategoryIds(for: room)
        guard !ids.isEmpty else { return ItemCategories.all }
        let set = Set(ids)
        let relevant = ids.compactMap { ItemCategories.byId[$0] }
        let other = ItemCategories.all.filter { !set.contains($0.id) }
        return relevant + other
    }

    /// When packing into a box, items are being kept — either moved with the user or dropped in storage.
    /// Surface that as the default so users only flip it for edge cases (donate/trash/sold).
    private var inferredDisposition: Disposition? {
        let destLabel = destinationRoom?.label.lowercased()
        let sourceLabel = sourceRoom?.label.lowercased()
        if destLabel?.contains("storage") == true || sourceLabel?.contains("storage") == true {
            return .storage
        }
        if destinationRoom != nil {
            return .moving
        }
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
