import SwiftUI

struct TriageCardView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(.pakt(.title))
                        .foregroundStyle(Color.paktForeground)
                        .lineLimit(2)
                    Spacer()
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.pakt(.heading))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
                metaRow
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktForeground.opacity(0.85))
                        .lineLimit(4)
                }
            }
            .padding(PaktSpace.s4)
        }
        .background(
            RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                .fill(Color.paktCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous))
    }

    @ViewBuilder private var photo: some View {
        ZStack(alignment: .topTrailing) {
            if let data = item.photos?.first?.data, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.paktMuted)
                    .overlay(
                        Image(paktIcon: "image")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.paktMutedForeground)
                    )
            }

            if item.fragility != .normal {
                PaktBadge(
                    item.fragility == .veryFragile ? "Very fragile" : "Fragile",
                    tone: .destructive
                )
                .padding(PaktSpace.s2)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipped()
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            if let cat = ItemCategories.lookup(item.categoryId) {
                Text(cat.label)
            }
            if let room = item.sourceRoom {
                Text("·")
                Text(room.label)
            }
        }
        .font(.pakt(.small))
        .foregroundStyle(Color.paktMutedForeground)
    }
}
