import SwiftData
import SwiftUI

/// Shown after scanning a box at the destination. Lets you mark the box
/// unpacked once every item has been placed.
struct UnpackView: View {
    @Bindable var box: Box

    @Environment(\.modelContext) private var context
    @State private var placedIds: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s4) {
                header
                itemsSection
                PaktButton("Mark box unpacked", size: .lg, action: finish)
                    .disabled(box.status == .unpacked)
                    .opacity(box.status == .unpacked ? 0.6 : 1)
            }
            .padding(PaktSpace.s4)
        }
        .background(Color.paktBackground)
        .navigationTitle("Unpack \(box.shortCode)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack {
                    PaktBadge(box.status.label, tone: box.status.tone)
                    Spacer()
                    Text(box.shortCode)
                        .font(.pakt(.mono).monospaced())
                        .foregroundStyle(Color.paktMutedForeground)
                }
                Text(box.boxType?.label ?? "No type")
                    .font(.pakt(.heading))
                if let dest = box.destinationRoom {
                    Text("→ \(dest.label)")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
    }

    private var itemsSection: some View {
        let liveBoxItems = (box.boxItems ?? []).filter { $0.item?.deletedAt == nil }
        return VStack(alignment: .leading, spacing: PaktSpace.s2) {
            HStack {
                Text("Contents").font(.pakt(.heading))
                Spacer()
                Text("\(placedIds.count) / \(liveBoxItems.count)")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
            VStack(spacing: 6) {
                ForEach(liveBoxItems, id: \.id) { bi in
                    if let item = bi.item {
                        Button { toggle(item) } label: {
                            ItemRow(item: item, placed: placedIds.contains(item.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if liveBoxItems.isEmpty {
                PaktCard {
                    Text("This box was packed empty.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
    }

    private func toggle(_ item: Item) {
        if placedIds.contains(item.id) { placedIds.remove(item.id) }
        else { placedIds.insert(item.id) }
    }

    private func finish() {
        box.status = .unpacked
        box.updatedAt = Date()
        try? context.save()
    }
}

private struct ItemRow: View {
    let item: Item
    let placed: Bool

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            Image(systemName: placed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(placed ? Color.paktMoving : Color.paktMutedForeground)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.pakt(.body))
                    .foregroundStyle(Color.paktForeground)
                    .strikethrough(placed, color: Color.paktMutedForeground)
                if let cat = ItemCategories.lookup(item.categoryId) {
                    Text(cat.label)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
            Spacer()
        }
        .padding(PaktSpace.s3)
        .background(RoundedRectangle(cornerRadius: PaktRadius.lg).fill(Color.paktCard))
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.lg)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
    }
}
