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
    @State private var showingDeleteConfirm = false
    @State private var deleted = false

    var body: some View {
        PaktScreen(accent: dispositionAccent) {
            heroHeader
            photosSurface
            itemSurface
            roomsSurface
            triageSurface
            overridesSurface
            notesSurface
            deleteButton
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DispositionChip(disposition: item.disposition.rawValue)
            }
        }
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
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        PaktHeroHeader(
            eyebrow: categoryLabel ?? "Item",
            title: item.name.isEmpty ? "Untitled" : item.name,
            subtitle: heroSubtitle,
            accent: dispositionAccent,
            titleStyle: .title
        ) {
            if item.quantity > 1 {
                VStack(spacing: 0) {
                    Text("×")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                    Text("\(item.quantity)")
                        .font(.pakt(.hero))
                        .foregroundStyle(dispositionAccent)
                        .contentTransition(.numericText(value: Double(item.quantity)))
                        .animation(PaktMotion.standard, value: item.quantity)
                }
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                        .fill(dispositionAccent.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                        .strokeBorder(dispositionAccent.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private var heroSubtitle: String {
        var parts: [String] = []
        if let src = item.sourceRoom?.label { parts.append(src) }
        if let dst = item.destinationRoom?.label { parts.append("→ \(dst)") }
        if parts.isEmpty { parts.append("Unassigned") }
        return parts.joined(separator: "  ")
    }

    private var categoryLabel: String? {
        ItemCategories.lookup(item.categoryId)?.label
    }

    // MARK: - Surfaces

    private var photosSurface: some View {
        PaktSurface(title: "Photos", icon: "camera", accent: .paktPrimary) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                PhotoStrip(item: item)
                HStack(spacing: PaktSpace.s2) {
                    PhotosPicker(selection: $pickerSelection, maxSelectionCount: 4, matching: .images) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                            Text("Pick photos")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaktButtonStyle(variant: .outline))

                    Button { showingCamera = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera")
                            Text("Camera")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaktButtonStyle(variant: .outline))
                }
            }
        }
    }

    private var itemSurface: some View {
        PaktSurface(title: "Item", icon: "box", accent: .paktPrimary) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                TextField("Name", text: $item.name)
                    .font(.pakt(.body))
                    .padding(PaktSpace.s2)
                    .background(
                        RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                            .fill(Color.paktMuted)
                    )

                PaktFieldStack {
                    PaktField("Quantity") {
                        Stepper("\(item.quantity)", value: $item.quantity, in: 1...999)
                            .labelsHidden()
                    }
                    PaktField("Category") {
                        Picker("Category", selection: Binding(
                            get: { item.categoryId ?? ItemCategories.defaultCategoryId },
                            set: { item.categoryId = $0 }
                        )) {
                            ForEach(ItemCategories.all) { cat in
                                Text(cat.label).tag(cat.id)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.paktForeground)
                    }
                }
            }
        }
    }

    @ViewBuilder private var roomsSurface: some View {
        if let move = item.move {
            PaktSurface(title: "Rooms", icon: "home", accent: .paktMoving) {
                PaktFieldStack {
                    PaktField("From") {
                        Picker("Source room", selection: Binding(
                            get: { item.sourceRoom?.id ?? "" },
                            set: { newId in
                                item.sourceRoom = (move.rooms ?? []).first { $0.id == newId && $0.deletedAt == nil }
                            }
                        )) {
                            Text("Unassigned").tag("")
                            ForEach(originRooms(of: move), id: \.id) { r in
                                Text(fullLabel(r)).tag(r.id)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.paktForeground)
                    }
                    PaktField("To") {
                        Picker("Destination room", selection: Binding(
                            get: { item.destinationRoom?.id ?? "" },
                            set: { newId in
                                item.destinationRoom = (move.rooms ?? []).first { $0.id == newId && $0.deletedAt == nil }
                            }
                        )) {
                            Text("Unassigned").tag("")
                            ForEach(destinationRooms(of: move), id: \.id) { r in
                                Text(fullLabel(r)).tag(r.id)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.paktForeground)
                    }
                }
            }
        }
    }

    private var triageSurface: some View {
        PaktSurface(title: "Triage", icon: "shuffle", accent: .paktDonate) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                // Disposition chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("Disposition")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(Disposition.allCases, id: \.self) { d in
                            DispositionPill(
                                label: dispositionLabel(d),
                                tint: dispositionTint(d),
                                isSelected: item.disposition == d
                            ) {
                                item.disposition = d
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                }

                // Fragility chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fragility")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    HStack(spacing: 6) {
                        ForEach([Fragility.normal, .fragile, .veryFragile], id: \.self) { f in
                            DispositionPill(
                                label: fragilityLabel(f),
                                tint: fragilityTint(f),
                                isSelected: item.fragility == f
                            ) {
                                item.fragility = f
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                }

                // Decide-for-me button
                PaktButton(variant: .outline, action: { showingDecisionQuiz = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Help me decide")
                        Spacer()
                        if let score = item.decisionScore {
                            Text(String(format: "%.2f", score))
                                .font(.pakt(.small).monospacedDigit())
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var overridesSurface: some View {
        PaktSurface(title: "Overrides", icon: "sliders") {
            PaktFieldStack {
                PaktField("Volume (cuft)") {
                    OverrideField(
                        placeholder: ItemCategories.lookup(item.categoryId).map { String(format: "%.2f", $0.volumeCuFtPerItem) } ?? "—",
                        value: $item.volumeCuFtOverride
                    )
                }
                PaktField("Weight (lbs)") {
                    OverrideField(
                        placeholder: ItemCategories.lookup(item.categoryId).map { String(format: "%.1f", $0.weightLbsPerItem) } ?? "—",
                        value: $item.weightLbsOverride
                    )
                }
            }
        }
    }

    private var notesSurface: some View {
        PaktSurface(title: "Notes", icon: "file-text") {
            TextField("Add notes", text: Binding(
                get: { item.notes ?? "" },
                set: { item.notes = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(3...8)
            .font(.pakt(.body))
            .foregroundStyle(Color.paktForeground)
            .padding(PaktSpace.s2)
            .background(
                RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                    .fill(Color.paktMuted)
            )
        }
    }

    private var deleteButton: some View {
        PaktButton(variant: .destructive, action: { showingDeleteConfirm = true }) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                Text("Delete item")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, PaktSpace.s2)
    }

    // MARK: - Computed

    private var dispositionAccent: Color {
        dispositionTint(item.disposition)
    }

    // MARK: - Actions

    private func performDelete() {
        let removed = item
        removed.deletedAt = Date()
        removed.updatedAt = Date()
        try? context.save()
        deleted = true
        dismiss()
        UndoToastCenter.shared.show(message: "\(removed.name) removed") {
            removed.deletedAt = nil
            removed.updatedAt = Date()
            try? context.save()
        }
    }

    // MARK: - Helpers

    private func originRooms(of move: Move) -> [Room] {
        (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .origin }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func destinationRooms(of move: Move) -> [Room] {
        (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .destination }
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

    private func dispositionTint(_ d: Disposition) -> Color {
        switch d {
        case .undecided: return .paktUndecided
        case .moving:    return .paktMoving
        case .storage:   return .paktStorage
        case .donate:    return .paktDonate
        case .trash:     return .paktTrash
        case .sold:      return .paktSold
        }
    }

    private func fragilityLabel(_ f: Fragility) -> String {
        switch f {
        case .normal:      return "Normal"
        case .fragile:     return "Fragile"
        case .veryFragile: return "Very fragile"
        }
    }

    private func fragilityTint(_ f: Fragility) -> Color {
        switch f {
        case .normal:      return .paktMutedForeground
        case .fragile:     return .paktDonate
        case .veryFragile: return .paktTrash
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

private struct PhotoStrip: View {
    let item: Item
    @Environment(\.modelContext) private var context

    private func removePhoto(_ photo: ItemPhoto) {
        photo.deletedAt = Date()
        try? context.save()
        UndoToastCenter.shared.show(message: "Photo removed") {
            photo.deletedAt = nil
            try? context.save()
        }
    }

    var body: some View {
        let photos = (item.photos ?? []).filter { $0.deletedAt == nil }
        if photos.isEmpty {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                        .strokeBorder(
                            Color.paktBorder,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(Color.paktMutedForeground.opacity(0.6))
                        )
                }
            }
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
                                        removePhoto(photo)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                            .font(.system(size: 20))
                                            .padding(4)
                                    }
                                    .accessibilityLabel("Remove photo")
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
    let placeholder: String
    @Binding var value: Double?

    @State private var text: String = ""

    var body: some View {
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
