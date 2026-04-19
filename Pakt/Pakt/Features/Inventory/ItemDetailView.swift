import PhotosUI
import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Bindable var item: Item

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingDecisionQuiz = false
    @State private var deleted = false

    var body: some View {
        Form {
            Section("Photos") {
                PhotoStrip(item: item)
                HStack {
                    PhotosPicker(selection: $pickerSelection, maxSelectionCount: 4, matching: .images) {
                        Label("Pick photos", systemImage: "photo")
                    }
                    Spacer()
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }
            }

            Section("Item") {
                TextField("Name", text: $item.name)
                Stepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...999)
                Picker("Category", selection: Binding(
                    get: { item.categoryId ?? ItemCategories.defaultCategoryId },
                    set: { item.categoryId = $0 }
                )) {
                    ForEach(ItemCategories.all) { cat in
                        Text(cat.label).tag(cat.id)
                    }
                }
            }

            Section("Rooms") {
                if let move = item.move {
                    Picker("Source room", selection: Binding(
                        get: { item.sourceRoom?.id ?? "" },
                        set: { newId in
                            item.sourceRoom = (move.rooms ?? []).first { $0.id == newId }
                        }
                    )) {
                        Text("Unassigned").tag("")
                        ForEach(originRooms(of: move), id: \.id) { r in
                            Text(fullLabel(r)).tag(r.id)
                        }
                    }
                    Picker("Destination room", selection: Binding(
                        get: { item.destinationRoom?.id ?? "" },
                        set: { newId in
                            item.destinationRoom = (move.rooms ?? []).first { $0.id == newId }
                        }
                    )) {
                        Text("Unassigned").tag("")
                        ForEach(destinationRooms(of: move), id: \.id) { r in
                            Text(fullLabel(r)).tag(r.id)
                        }
                    }
                }
            }

            Section("Triage") {
                Picker("Disposition", selection: $item.disposition) {
                    ForEach(Disposition.allCases, id: \.self) { d in
                        Text(dispositionLabel(d)).tag(d)
                    }
                }
                Picker("Fragility", selection: $item.fragility) {
                    Text("Normal").tag(Fragility.normal)
                    Text("Fragile").tag(Fragility.fragile)
                    Text("Very fragile").tag(Fragility.veryFragile)
                }
                Button {
                    showingDecisionQuiz = true
                } label: {
                    HStack {
                        Label("Help me decide", systemImage: "sparkles")
                        Spacer()
                        if let score = item.decisionScore {
                            Text(String(format: "%.2f", score))
                                .font(.pakt(.small).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Overrides") {
                OverrideField(label: "Volume (cuft)",
                              placeholder: ItemCategories.lookup(item.categoryId).map { String(format: "%.2f", $0.volumeCuFtPerItem) } ?? "—",
                              value: $item.volumeCuFtOverride)
                OverrideField(label: "Weight (lbs)",
                              placeholder: ItemCategories.lookup(item.categoryId).map { String(format: "%.1f", $0.weightLbsPerItem) } ?? "—",
                              value: $item.weightLbsOverride)
            }

            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { item.notes ?? "" },
                    set: { item.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...8)
            }

            Section {
                Button(role: .destructive) {
                    item.deletedAt = Date()
                    try? context.save()
                    deleted = true
                    dismiss()
                } label: {
                    Label("Delete item", systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paktBackground)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerSelection) { _, newItems in
            Task { await attachPicked(newItems) }
        }
        .onDisappear {
            if !deleted {
                item.updatedAt = Date()
                try? context.save()
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { image in
                attachCaptured(image)
            }
        }
        .sheet(isPresented: $showingDecisionQuiz) {
            DecisionQuizView(item: item)
        }
    }

    // MARK: - Helpers

    private func originRooms(of move: Move) -> [Room] {
        (move.rooms ?? []).filter { $0.kind == .origin }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func destinationRooms(of move: Move) -> [Room] {
        (move.rooms ?? []).filter { $0.kind == .destination }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func fullLabel(_ room: Room) -> String {
        room.parentRoom.map { "\($0.label) › \(room.label)" } ?? room.label
    }

    private func dispositionLabel(_ d: Disposition) -> String {
        switch d {
        case .undecided: return "Undecided"
        case .moving:    return "Moving"
        case .storage:   return "Storage"
        case .donate:    return "Donate"
        case .trash:     return "Trash"
        case .sold:      return "Sold"
        }
    }

    // MARK: - Photo attaching

    private func attachPicked(_ selection: [PhotosPickerItem]) async {
        for picked in selection {
            guard let raw = try? await picked.loadTransferable(type: Data.self) else { continue }
            addPhoto(from: raw)
        }
        pickerSelection = []
    }

    private func attachCaptured(_ image: UIImage) {
        guard let data = ImageCompressor.compressed(image) else { return }
        addPhoto(from: data)
    }

    private func addPhoto(from raw: Data) {
        guard let image = UIImage(data: raw),
              let compressed = ImageCompressor.compressed(image)
        else { return }
        let size = UIImage(data: compressed)?.size
        let photo = ItemPhoto(
            item: item,
            data: compressed,
            width: size.map { Int($0.width) },
            height: size.map { Int($0.height) },
            byteSize: compressed.count,
            contentType: "image/jpeg"
        )
        context.insert(photo)
        try? context.save()
    }
}

private struct PhotoStrip: View {
    let item: Item
    @Environment(\.modelContext) private var context

    var body: some View {
        let photos = item.photos ?? []
        if photos.isEmpty {
            Text("No photos yet.")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos, id: \.id) { photo in
                        if let data = photo.data, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: PaktRadius.md))
                                .overlay(alignment: .topTrailing) {
                                    Button(role: .destructive) {
                                        context.delete(photo)
                                        try? context.save()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                            .font(.system(size: 20))
                                            .padding(4)
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct OverrideField: View {
    let label: String
    let placeholder: String
    @Binding var value: Double?

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .onAppear {
                    if let v = value { text = String(v) }
                }
                .onChange(of: text) { _, new in
                    value = Double(new)
                }
        }
    }
}
