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
            PaktScreen(accent: .paktPrimary) {
                PaktHeroHeader(
                    eyebrow: sourceRoom?.label ?? "New",
                    title: "Add item",
                    subtitle: sourceRoom.map { "In \($0.label)" } ?? "Loose item",
                    accent: .paktPrimary,
                    titleStyle: .title
                )

                itemSurface
                categorySurface
                triageSurface
                notesSurface
            }
            .navigationTitle("")
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
                        .foregroundStyle(canSubmit ? Color.paktPrimary : Color.paktMutedForeground)
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

    // MARK: - Surfaces

    private var itemSurface: some View {
        PaktSurface(title: "Item", icon: "box", accent: .paktPrimary) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                TextField("Name", text: $name)
                    .font(.pakt(.title))
                    .foregroundStyle(Color.paktForeground)
                    .padding(PaktSpace.s3)
                    .background(
                        RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                            .fill(Color.paktMuted)
                    )

                PaktField("Quantity") {
                    Stepper("\(quantity)", value: $quantity, in: 1...999)
                        .labelsHidden()
                }
            }
        }
    }

    private var categorySurface: some View {
        PaktSurface(title: "Category", icon: "tag", accent: .paktStorage) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                Picker("Category", selection: $categoryId) {
                    ForEach(orderedCategories) { cat in
                        Text(cat.label).tag(cat.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, PaktSpace.s3)
                .padding(.vertical, PaktSpace.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                        .fill(Color.paktMuted)
                )
                .tint(Color.paktForeground)

                if let cat = ItemCategories.lookup(categoryId) {
                    PaktFieldStack {
                        PaktField("Typical volume") {
                            Text("\(cat.volumeCuFtPerItem, specifier: "%.2f") cuft")
                        }
                        PaktField("Typical weight") {
                            Text("\(cat.weightLbsPerItem, specifier: "%.1f") lbs")
                        }
                    }
                }
            }
        }
    }

    private var triageSurface: some View {
        PaktSurface(title: "Triage", icon: "shuffle", accent: .paktDonate) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Disposition")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(Disposition.allCases, id: \.self) { d in
                            DispositionPill(
                                label: label(for: d),
                                tint: tint(for: d),
                                isSelected: disposition == d
                            ) {
                                disposition = d
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fragility")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    HStack(spacing: 6) {
                        DispositionPill(label: "Normal", tint: .paktMutedForeground, isSelected: fragility == .normal) {
                            fragility = .normal
                        }
                        DispositionPill(label: "Fragile", tint: .paktDonate, isSelected: fragility == .fragile) {
                            fragility = .fragile
                        }
                        DispositionPill(label: "Very fragile", tint: .paktTrash, isSelected: fragility == .veryFragile) {
                            fragility = .veryFragile
                        }
                    }
                }
            }
        }
    }

    private var notesSurface: some View {
        PaktSurface(title: "Notes", icon: "file-text") {
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.pakt(.body))
                .foregroundStyle(Color.paktForeground)
                .padding(PaktSpace.s2)
                .background(
                    RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                        .fill(Color.paktMuted)
                )
        }
    }

    // MARK: - Submit

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

    private var orderedCategories: [ItemCategory] {
        guard let room = sourceRoom else { return ItemCategories.all }
        let ids = relevantCategoryIds(for: room)
        guard !ids.isEmpty else { return ItemCategories.all }
        let set = Set(ids)
        let relevant = ids.compactMap { ItemCategories.byId[$0] }
        let other = ItemCategories.all.filter { !set.contains($0.id) }
        return relevant + other
    }

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

    private func tint(for d: Disposition) -> Color {
        switch d {
        case .undecided: return .paktUndecided
        case .moving:    return .paktMoving
        case .storage:   return .paktStorage
        case .donate:    return .paktDonate
        case .trash:     return .paktTrash
        case .sold:      return .paktSold
        }
    }
}

private struct DispositionPill: View {
    let label: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark" : "circle.dotted")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.pakt(.small))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.paktPrimaryForeground : Color.paktForeground)
            .background(
                Capsule().fill(isSelected ? tint : Color.paktMuted)
            )
        }
        .buttonStyle(.plain)
    }
}
