import SwiftData
import SwiftUI

/// Shown after scanning a box that isn't delivered yet. Quick-add items,
/// advance status, review contents.
struct PackView: View {
    @Bindable var box: Box

    @Environment(\.modelContext) private var context
    @State private var showingAddItems = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s4) {
                header
                itemsSection
                actionsSection
            }
            .padding(PaktSpace.s4)
        }
        .background(Color.paktBackground)
        .navigationTitle("Pack \(box.shortCode)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddItems) {
            BoxItemPickerSheet(box: box).presentationDetents([.large])
        }
    }

    // MARK: - Sections

    private var header: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack {
                    PaktBadge(box.status.label, tone: box.status.tone)
                    Spacer()
                    if let next = box.status.nextStatus {
                        PaktButton("Advance to \(next.label)", size: .sm) {
                            box.status = next
                            box.updatedAt = Date()
                            try? context.save()
                        }
                    }
                }
                Text(box.boxType?.label ?? "No type")
                    .font(.pakt(.heading))
                    .foregroundStyle(Color.paktForeground)
                if let dest = box.destinationRoom {
                    Text("→ \(dest.label)")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                if !box.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(box.tags, id: \.self) { tag in
                            PaktBadge(tag.label, tone: tag == .fragile ? .destructive : .outline)
                        }
                    }
                }
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: PaktSpace.s2) {
            HStack {
                Text("Contents").font(.pakt(.heading))
                Spacer()
                Text("\((box.boxItems ?? []).count)")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
            if (box.boxItems ?? []).isEmpty {
                PaktCard {
                    Text("No items yet. Tap below to add some.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(box.boxItems ?? [], id: \.id) { bi in
                        if let item = bi.item {
                            ItemRow(item: item, quantity: bi.quantity, onRemove: {
                                context.delete(bi)
                                try? context.save()
                            })
                        }
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: PaktSpace.s2) {
            PaktButton("Add items", size: .lg) { showingAddItems = true }
        }
    }
}

private struct ItemRow: View {
    let item: Item
    let quantity: Int
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.pakt(.body))
                    .foregroundStyle(Color.paktForeground)
                if let cat = ItemCategories.lookup(item.categoryId) {
                    Text(cat.label)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
            Spacer()
            Text("×\(quantity)")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Color.paktDestructive)
            }
            .buttonStyle(.plain)
        }
        .padding(PaktSpace.s3)
        .background(RoundedRectangle(cornerRadius: PaktRadius.lg).fill(Color.paktCard))
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.lg)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
    }
}
