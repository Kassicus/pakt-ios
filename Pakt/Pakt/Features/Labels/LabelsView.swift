import SwiftData
import SwiftUI

struct LabelsView: View {
    let move: Move

    @State private var selectedIds: Set<String> = []
    @State private var savedCount: Int = 0
    @State private var showSavedToast = false
    @State private var sharePayload: [UIImage] = []
    @State private var shareIsPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(liveBoxes, id: \.id) { box in
                        LabelTile(
                            box: box,
                            isSelected: selectedIds.contains(box.id),
                            onTap: { toggle(box) }
                        )
                    }
                }
                .padding(PaktSpace.s4)
                .padding(.bottom, 80)
            }
            .background(Color.paktBackground)

            if !selectedIds.isEmpty {
                actionBar
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.bottom, PaktSpace.s4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showSavedToast {
                Text("Saved \(savedCount) label\(savedCount == 1 ? "" : "s") to Photos")
                    .font(.pakt(.small))
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.paktCard))
                    .overlay(Capsule().strokeBorder(Color.paktBorder, lineWidth: 1))
                    .padding(.bottom, 100)
                    .transition(.opacity)
            }
        }
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !liveBoxes.isEmpty {
                    Button(allSelected ? "Deselect" : "Select all") {
                        if allSelected {
                            selectedIds.removeAll()
                        } else {
                            selectedIds = Set(liveBoxes.map(\.id))
                        }
                    }
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktPrimary)
                }
            }
        }
        .sheet(isPresented: $shareIsPresented) {
            ActivityView(items: sharePayload)
        }
        .overlay {
            if liveBoxes.isEmpty { emptyState }
        }
    }

    // MARK: - Subviews

    private var actionBar: some View {
        HStack(spacing: PaktSpace.s2) {
            PaktButton(variant: .outline, action: shareSelected) {
                HStack { Image(systemName: "square.and.arrow.up"); Text("Share") }
                    .frame(maxWidth: .infinity)
            }
            PaktButton(action: saveSelectedToPhotos) {
                HStack { Image(systemName: "arrow.down.to.line"); Text("Save to Photos") }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(PaktSpace.s2)
        .background(
            RoundedRectangle(cornerRadius: PaktRadius.xl)
                .fill(Color.paktCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.xl)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: PaktSpace.s2) {
            Image(paktIcon: "qr-code")
                .font(.system(size: 44))
                .foregroundStyle(Color.paktMutedForeground)
            Text("No labels yet").font(.pakt(.heading))
            Text("Create a box, then come back to print a label.")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
        }
        .padding(PaktSpace.s6)
    }

    // MARK: - Data

    private var liveBoxes: [Box] {
        (move.boxes ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var allSelected: Bool {
        !liveBoxes.isEmpty && selectedIds.count == liveBoxes.count
    }

    private func toggle(_ box: Box) {
        if selectedIds.contains(box.id) { selectedIds.remove(box.id) }
        else { selectedIds.insert(box.id) }
    }

    // MARK: - Actions

    private func saveSelectedToPhotos() {
        let images = selectedBoxes.compactMap { LabelRenderer.image(for: $0) }
        guard !images.isEmpty else { return }
        for image in images {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        savedCount = images.count
        selectedIds.removeAll()
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSavedToast = false }
        }
    }

    private func shareSelected() {
        let images = selectedBoxes.compactMap { LabelRenderer.image(for: $0) }
        guard !images.isEmpty else { return }
        sharePayload = images
        shareIsPresented = true
    }

    private var selectedBoxes: [Box] {
        liveBoxes.filter { selectedIds.contains($0.id) }
    }
}

// MARK: - Tile

private struct LabelTile: View {
    let box: Box
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                if let img = LabelRenderer.image(for: box) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(472.0 / 354.0, contentMode: .fit)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: PaktRadius.md))
                } else {
                    RoundedRectangle(cornerRadius: PaktRadius.md)
                        .fill(Color.paktMuted)
                        .frame(height: 90)
                }
                Text(box.shortCode)
                    .font(.pakt(.mono).monospaced())
                    .foregroundStyle(Color.paktForeground)
                Text(box.boxType?.label ?? "")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .lineLimit(1)
            }
            .padding(PaktSpace.s2)
            .background(RoundedRectangle(cornerRadius: PaktRadius.lg).fill(Color.paktCard))
            .overlay(
                RoundedRectangle(cornerRadius: PaktRadius.lg)
                    .strokeBorder(isSelected ? Color.paktPrimary : Color.paktBorder,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share sheet wrapper

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
