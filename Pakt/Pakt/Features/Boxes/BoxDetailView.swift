import SwiftData
import SwiftUI
import TipKit

struct BoxDetailView: View {
    @Bindable var box: Box

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddItems = false
    @State private var showingNewItem = false
    @State private var showingDeleteConfirm = false
    @State private var deleted = false
    @State private var pendingRemoval: BoxItem?
    @State private var showLabelSavedToast = false
    private let swipeTip = SwipeToRemoveBoxItemTip()

    private var labelAtTop: Bool { box.status >= .sealed }

    var body: some View {
        ZStack(alignment: .bottom) {
            PaktScreen(accent: statusAccent) {
                heroHeader
                heroActions

                if labelAtTop { labelSurface }

                contentsSurface
                typeAndRoomsSurface
                tagsSurface
                detailsSurface

                if !labelAtTop { labelSurface }

                deleteButton
            }

            if showLabelSavedToast {
                Text("Saved label to Photos")
                    .font(.pakt(.small))
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.paktCard))
                    .overlay(Capsule().strokeBorder(Color.paktBorder, lineWidth: 1))
                    .padding(.bottom, PaktSpace.s6)
                    .transition(.opacity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PaktBadge(box.status.label, tone: box.status.tone)
            }
        }
        .sheet(isPresented: $showingAddItems) {
            BoxItemPickerSheet(box: box).presentationDetents([.large])
        }
        .sheet(isPresented: $showingNewItem) {
            AddItemSheet(
                move: box.move,
                sourceRoom: box.sourceRoom,
                destinationRoom: box.destinationRoom,
                onCreate: attach
            )
            .presentationDetents([.large])
        }
        .confirmationDialog(
            "Remove from this box?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let target = pendingRemoval {
                    confirmedRemove(boxItem: target)
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("The item stays in your inventory — only its placement in this box is removed.")
        }
        .confirmationDialog(
            "Delete this box?",
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
            eyebrow: "Box",
            title: box.shortCode,
            subtitle: heroSubtitle,
            accent: statusAccent,
            titleStyle: .hero
        ) {
            Image(paktIcon: "box")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(statusAccent)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                        .fill(statusAccent.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                        .strokeBorder(statusAccent.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private var heroSubtitle: String {
        let type = box.boxType?.label ?? "No type"
        let dest = box.destinationRoom?.label ?? "No destination"
        return "\(type)  •  \(dest)"
    }

    private var heroActions: some View {
        PaktSurface(accent: statusAccent, padding: PaktSpace.s4) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(box.status.label.uppercased())
                        .font(.pakt(.small))
                        .tracking(1.0)
                        .foregroundStyle(statusAccent)
                    Spacer()
                    if let next = box.status.nextStatus {
                        Text("Next: \(next.label)")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
                BoxStatusTrack(current: box.status)
                HStack(spacing: PaktSpace.s2) {
                    PaktButton(variant: .outline, action: { step(backwards: true) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(box.status.previousStatus == nil)
                    .opacity(box.status.previousStatus == nil ? 0.5 : 1)

                    if let next = box.status.nextStatus {
                        PaktButton(action: { advance(to: next) }) {
                            HStack(spacing: 4) {
                                Text("Advance to \(next.label)")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Surfaces

    private var contentsSurface: some View {
        PaktSurface(title: "Contents", icon: "package-open", accent: .paktStorage) {
            VStack(alignment: .leading, spacing: 0) {
                if #available(iOS 17.0, *), !liveItems.isEmpty {
                    TipView(swipeTip)
                        .padding(.bottom, PaktSpace.s2)
                }
                if liveItems.isEmpty {
                    Text("No items yet.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .padding(.vertical, PaktSpace.s2)
                } else {
                    ForEach(Array(liveItems.enumerated()), id: \.element.id) { idx, bi in
                        if idx > 0 {
                            Rectangle()
                                .fill(Color.paktBorder.opacity(0.6))
                                .frame(height: 1)
                                .padding(.vertical, 4)
                        }
                        contentRow(boxItem: bi)
                    }
                }

                HStack(spacing: PaktSpace.s2) {
                    PaktButton(variant: .outline, action: { showingAddItems = true }) {
                        HStack(spacing: 4) {
                            Image(paktIcon: "tray.full")
                            Text("From inventory")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    PaktButton(variant: .outline, action: { showingNewItem = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("New item")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, PaktSpace.s3)
            }
        }
    }

    @ViewBuilder
    private func contentRow(boxItem bi: BoxItem) -> some View {
        if let item = bi.item {
            HStack(spacing: PaktSpace.s3) {
                Text(item.name)
                    .font(.pakt(.body))
                    .foregroundStyle(Color.paktForeground)
                Spacer()
                Text("×\(bi.quantity)")
                    .font(.pakt(.small).monospacedDigit())
                    .foregroundStyle(Color.paktMutedForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.paktMuted))
                Button {
                    pendingRemoval = bi
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.name)")
            }
            .padding(.vertical, 6)
        }
    }

    private var typeAndRoomsSurface: some View {
        PaktSurface(title: "Placement", icon: "home", accent: .paktMoving) {
            PaktFieldStack {
                PaktField("Box type") {
                    Picker("Box type", selection: Binding(
                        get: { box.boxType?.id ?? "" },
                        set: { setType(to: $0) }
                    )) {
                        ForEach(availableBoxTypes, id: \.id) { t in
                            Text(t.label).tag(t.id)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.paktForeground)
                }
                PaktField("From") {
                    Picker("Source room", selection: Binding(
                        get: { box.sourceRoom?.id ?? "" },
                        set: { setSource(to: $0) }
                    )) {
                        Text("None").tag("")
                        ForEach(originRooms, id: \.id) { r in
                            Text(fullLabel(r)).tag(r.id)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.paktForeground)
                }
                PaktField("To") {
                    Picker("Destination", selection: Binding(
                        get: { box.destinationRoom?.id ?? "" },
                        set: { setDestination(to: $0) }
                    )) {
                        Text("None").tag("")
                        ForEach(destinationRooms, id: \.id) { r in
                            Text(fullLabel(r)).tag(r.id)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.paktForeground)
                }
            }
        }
    }

    private var tagsSurface: some View {
        PaktSurface(title: "Tags", icon: "tag", accent: .paktDonate) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(BoxTag.allCases, id: \.self) { tag in
                    let on = box.tags.contains(tag)
                    Button { toggleTag(tag, on: !on) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: on ? "checkmark" : "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text(tag.label)
                                .font(.pakt(.small))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(on ? Color.paktPrimaryForeground : Color.paktForeground)
                        .background(
                            Capsule().fill(on ? Color.paktDonate : Color.paktMuted)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsSurface: some View {
        PaktSurface(title: "Details", icon: "file-text") {
            PaktFieldStack {
                PaktField("Weight (lbs)") {
                    TextField("Optional", value: $box.weightLbsActual, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    TextField("Optional", text: Binding(
                        get: { box.notes ?? "" },
                        set: { box.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                    .font(.pakt(.body))
                    .foregroundStyle(Color.paktForeground)
                    .padding(PaktSpace.s2)
                    .background(
                        RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                            .fill(Color.paktMuted)
                    )
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder private var labelSurface: some View {
        PaktSurface(title: "Label", icon: "qr-code", accent: .paktPrimary) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                if let img = LabelRenderer.image(for: box) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(472.0 / 354.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: PaktRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: PaktRadius.md)
                                .strokeBorder(Color.paktBorder, lineWidth: 1)
                        )
                } else {
                    Text("Label preview unavailable")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                PaktButton(variant: .outline, action: saveLabelToPhotos) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.to.line")
                        Text("Save label to Photos")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var deleteButton: some View {
        PaktButton(variant: .destructive, action: { showingDeleteConfirm = true }) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                Text("Delete box")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, PaktSpace.s2)
    }

    // MARK: - Computed

    private var liveItems: [BoxItem] {
        (box.boxItems ?? []).filter { $0.item?.deletedAt == nil }
    }

    private var statusAccent: Color {
        switch box.status {
        case .empty:     return .paktMutedForeground
        case .packing:   return .paktPrimary
        case .sealed:    return .paktStorage
        case .loaded:    return .paktStorage
        case .inTransit: return .paktMoving
        case .delivered: return .paktMoving
        case .unpacked:  return .paktAccent
        }
    }

    // MARK: - Actions

    private func saveLabelToPhotos() {
        guard let image = LabelRenderer.image(for: box) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation { showLabelSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showLabelSavedToast = false }
        }
    }

    private func attach(_ item: Item) {
        let bi = BoxItem(box: box, item: item, quantity: item.quantity)
        context.insert(bi)
        box.updatedAt = Date()
        if box.status == .empty { box.status = .packing }
        try? context.save()
    }

    private func performDelete() {
        let removed = box
        removed.deletedAt = Date()
        removed.updatedAt = Date()
        try? context.save()
        deleted = true
        dismiss()
        UndoToastCenter.shared.show(message: "Box \(removed.shortCode) removed") {
            removed.deletedAt = nil
            removed.updatedAt = Date()
            try? context.save()
        }
    }

    private var availableBoxTypes: [BoxType] {
        (box.move?.boxTypes ?? []).filter { $0.deletedAt == nil }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private var originRooms: [Room] {
        (box.move?.rooms ?? []).filter { $0.kind == .origin }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private var destinationRooms: [Room] {
        (box.move?.rooms ?? []).filter { $0.kind == .destination }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }
    }

    private func fullLabel(_ r: Room) -> String {
        r.parentRoom.map { "\($0.label) › \(r.label)" } ?? r.label
    }

    private func setType(to id: String) {
        box.boxType = availableBoxTypes.first { $0.id == id }
    }

    private func setSource(to id: String) {
        box.sourceRoom = originRooms.first { $0.id == id }
    }

    private func setDestination(to id: String) {
        box.destinationRoom = destinationRooms.first { $0.id == id }
    }

    private func toggleTag(_ tag: BoxTag, on: Bool) {
        var current = box.tags
        if on, !current.contains(tag) { current.append(tag) }
        if !on { current.removeAll { $0 == tag } }
        box.tags = current
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func confirmedRemove(boxItem: BoxItem) {
        context.delete(boxItem)
        try? context.save()
        DeletionTipEvents.userDidSwipeToDelete()
    }

    private func step(backwards: Bool) {
        let target = backwards ? box.status.previousStatus : box.status.nextStatus
        guard let t = target else { return }
        advance(to: t)
    }

    private func advance(to next: BoxStatus) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        box.status = next
        box.updatedAt = Date()
        try? context.save()
    }
}
