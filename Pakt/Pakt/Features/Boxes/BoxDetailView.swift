import SwiftData
import SwiftUI
import TipKit

struct BoxDetailView: View {
    @Bindable var box: Box

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddItems = false
    @State private var showingNewItem = false
    @State private var deleted = false
    @State private var pendingRemoval: IndexSet?
    private let swipeTip = SwipeToRemoveBoxItemTip()

    var body: some View {
        Form {
            Section("Status") {
                HStack {
                    PaktBadge(box.status.label, tone: box.status.tone)
                    Spacer()
                    Text(box.shortCode)
                        .font(.pakt(.mono).monospaced())
                        .foregroundStyle(Color.paktMutedForeground)
                }
                HStack(spacing: PaktSpace.s2) {
                    Button { step(backwards: true) } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(box.status.previousStatus == nil)
                    .buttonStyle(.bordered)

                    Spacer()

                    if let next = box.status.nextStatus {
                        Button {
                            box.status = next
                            box.updatedAt = Date()
                            try? context.save()
                        } label: {
                            HStack {
                                Text("Advance to \(next.label)")
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.paktPrimary)
                    }
                }
            }

            Section("Contents") {
                let liveItems = (box.boxItems ?? []).filter { $0.item?.deletedAt == nil }
                if !liveItems.isEmpty {
                    if #available(iOS 17.0, *) {
                        TipView(swipeTip)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(liveItems, id: \.id) { bi in
                        if let item = bi.item {
                            HStack {
                                Text(item.name).font(.pakt(.body))
                                Spacer()
                                Text("×\(bi.quantity)")
                                    .font(.pakt(.small))
                                    .foregroundStyle(Color.paktMutedForeground)
                            }
                        }
                    }
                    .onDelete { offsets in pendingRemoval = offsets }
                } else {
                    Text("No items yet.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                Menu {
                    Button {
                        showingNewItem = true
                    } label: {
                        Label("New item", systemImage: "sparkles")
                    }
                    Button {
                        showingAddItems = true
                    } label: {
                        Label("From inventory", systemImage: "tray.full")
                    }
                } label: {
                    Label("Add items", systemImage: "plus")
                }
            }

            Section("Type & rooms") {
                Picker("Box type", selection: Binding(
                    get: { box.boxType?.id ?? "" },
                    set: { box.boxType = availableBoxTypes.first { $0.id == $0.id } ?? box.boxType; setType(to: $0) }
                )) {
                    ForEach(availableBoxTypes, id: \.id) { t in
                        Text(t.label).tag(t.id)
                    }
                }
                Picker("Source room", selection: Binding(
                    get: { box.sourceRoom?.id ?? "" },
                    set: { setSource(to: $0) }
                )) {
                    Text("None").tag("")
                    ForEach(originRooms, id: \.id) { r in
                        Text(fullLabel(r)).tag(r.id)
                    }
                }
                Picker("Destination", selection: Binding(
                    get: { box.destinationRoom?.id ?? "" },
                    set: { setDestination(to: $0) }
                )) {
                    Text("None").tag("")
                    ForEach(destinationRooms, id: \.id) { r in
                        Text(fullLabel(r)).tag(r.id)
                    }
                }
            }

            Section("Tags") {
                ForEach(BoxTag.allCases, id: \.self) { tag in
                    Toggle(tag.label, isOn: Binding(
                        get: { box.tags.contains(tag) },
                        set: { on in toggleTag(tag, on: on) }
                    ))
                }
            }

            Section("Details") {
                HStack {
                    Text("Weight (lbs)")
                    Spacer()
                    TextField("Optional", value: $box.weightLbsActual, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
                TextField("Notes", text: Binding(
                    get: { box.notes ?? "" },
                    set: { box.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            Section {
                Button(role: .destructive) {
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
                } label: {
                    Label("Delete box", systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paktBackground)
        .navigationTitle(box.shortCode)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddItems) {
            BoxItemPickerSheet(box: box).presentationDetents([.large])
        }
        .sheet(isPresented: $showingNewItem) {
            AddItemSheet(
                move: box.move,
                sourceRoom: box.sourceRoom,
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
                if let offsets = pendingRemoval {
                    confirmedRemoveItems(at: offsets)
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("The item stays in your inventory — only its placement in this box is removed.")
        }
    }

    private func attach(_ item: Item) {
        let bi = BoxItem(box: box, item: item, quantity: item.quantity)
        context.insert(bi)
        box.updatedAt = Date()
        if box.status == .empty { box.status = .packing }
        try? context.save()
    }

    // MARK: - Helpers

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

    // MARK: - Mutations

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
    }

    private func confirmedRemoveItems(at offsets: IndexSet) {
        let liveItems = (box.boxItems ?? []).filter { $0.item?.deletedAt == nil }
        for index in offsets where index < liveItems.count {
            context.delete(liveItems[index])
        }
        try? context.save()
        DeletionTipEvents.userDidSwipeToDelete()
    }

    private func step(backwards: Bool) {
        let target = backwards ? box.status.previousStatus : box.status.nextStatus
        guard let t = target else { return }
        box.status = t
        box.updatedAt = Date()
        try? context.save()
    }
}
