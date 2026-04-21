import SwiftData
import SwiftUI

struct BoxesListView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @State private var showingNewBox = false
    @State private var showingBoxTypes = false
    @State private var pendingDelete: Box?

    var body: some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingNewBox = true } label: {
                            Label("New box", systemImage: "plus")
                        }
                        Button { showingBoxTypes = true } label: {
                            Label("Box types", systemImage: "cube")
                        }
                    } label: {
                        Image(paktIcon: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewBox) {
                NewBoxSheet(move: move).presentationDetents([.large])
            }
            .sheet(isPresented: $showingBoxTypes) {
                NavigationStack { BoxTypesView(move: move) }
            }
            .confirmationDialog(
                "Delete this box?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let box = pendingDelete { softDelete(box) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
    }

    @ViewBuilder private var content: some View {
        if liveBoxes.isEmpty {
            PaktScreen(accent: .paktStorage) {
                heroHeader
                PaktEmptyState(
                    icon: "box",
                    title: "No boxes yet",
                    message: boxTypesAvailable.isEmpty
                        ? "Add a box type first, then create your first box."
                        : "Create a box, then add items to it as you pack.",
                    accent: .paktStorage,
                    primary: boxTypesAvailable.isEmpty
                        ? .init("Manage box types") { showingBoxTypes = true }
                        : .init("Create a box") { showingNewBox = true },
                    secondary: boxTypesAvailable.isEmpty
                        ? nil
                        : .init("Manage box types") { showingBoxTypes = true }
                )
            }
        } else {
            PaktScreen(accent: .paktStorage) {
                heroHeader
                ForEach(statusGroups, id: \.status) { group in
                    statusSection(group)
                }
            }
        }
    }

    private var heroHeader: some View {
        PaktHeroHeader(
            eyebrow: "Packing",
            title: "Boxes",
            subtitle: subtitle,
            accent: .paktStorage,
            titleStyle: .hero
        ) {
            Text("\(liveBoxes.count)")
                .font(.pakt(.hero))
                .foregroundStyle(Color.paktStorage)
                .contentTransition(.numericText(value: Double(liveBoxes.count)))
                .animation(PaktMotion.standard, value: liveBoxes.count)
        }
    }

    private var subtitle: String {
        if liveBoxes.isEmpty { return "No boxes yet" }
        let sealedAndUp = liveBoxes.filter { $0.status >= .sealed }.count
        return "\(sealedAndUp)/\(liveBoxes.count) sealed"
    }

    @ViewBuilder
    private func statusSection(_ group: StatusGroup) -> some View {
        VStack(alignment: .leading, spacing: PaktSpace.s2) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accentFor(group.status))
                    .frame(width: 14, height: 2)
                    .clipShape(Capsule())
                Image(paktIcon: iconFor(group.status))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentFor(group.status))
                Text(group.status.label.uppercased())
                    .font(.pakt(.small))
                    .tracking(1.2)
                    .foregroundStyle(accentFor(group.status))
                Spacer()
                Text("\(group.boxes.count)")
                    .font(.pakt(.small).monospacedDigit())
                    .foregroundStyle(Color.paktMutedForeground)
                    .contentTransition(.numericText(value: Double(group.boxes.count)))
                    .animation(PaktMotion.standard, value: group.boxes.count)
            }
            .padding(.top, PaktSpace.s2)

            VStack(spacing: PaktSpace.s2) {
                ForEach(group.boxes, id: \.id) { box in
                    NavigationLink { BoxDetailView(box: box) } label: {
                        BoxRow(
                            box: box,
                            accent: accentFor(box.status),
                            onDelete: { pendingDelete = box }
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { pendingDelete = box } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private struct StatusGroup {
        let status: BoxStatus
        let boxes: [Box]
    }

    private var liveBoxes: [Box] {
        (move.boxes ?? []).filter { $0.deletedAt == nil }
    }

    private var boxTypesAvailable: [BoxType] {
        (move.boxTypes ?? []).filter { $0.deletedAt == nil }
    }

    private var statusGroups: [StatusGroup] {
        BoxStatus.ordered.compactMap { status in
            let boxes = liveBoxes
                .filter { $0.status == status }
                .sorted { $0.createdAt > $1.createdAt }
            guard !boxes.isEmpty else { return nil }
            return StatusGroup(status: status, boxes: boxes)
        }
    }

    private func iconFor(_ status: BoxStatus) -> String {
        switch status {
        case .empty:     return "circle"
        case .packing:   return "package-open"
        case .sealed:    return "lock"
        case .loaded:    return "truck"
        case .inTransit: return "truck"
        case .delivered: return "check-circle"
        case .unpacked:  return "package-open"
        }
    }

    private func accentFor(_ status: BoxStatus) -> Color {
        switch status {
        case .empty:     return .paktMutedForeground
        case .packing:   return .paktPrimary
        case .sealed:    return .paktStorage
        case .loaded:    return .paktStorage
        case .inTransit: return .paktMoving
        case .delivered: return .paktMoving
        case .unpacked:  return .paktAccent
        }
    }

    private func softDelete(_ box: Box) {
        let now = Date()
        box.deletedAt = now
        box.updatedAt = now
        try? context.save()
        DeletionTipEvents.userDidSwipeToDelete()

        UndoToastCenter.shared.show(message: "Box \(box.shortCode) removed") {
            box.deletedAt = nil
            box.updatedAt = Date()
            try? context.save()
        }
    }
}

// MARK: - Row

private struct BoxRow: View {
    let box: Box
    let accent: Color
    let onDelete: () -> Void

    var body: some View {
        PaktSurface(accent: accent, padding: PaktSpace.s3) {
            HStack(alignment: .top, spacing: PaktSpace.s3) {
                VStack(alignment: .center, spacing: 2) {
                    Text(box.shortCode)
                        .font(.pakt(.mono).monospaced())
                        .foregroundStyle(accent)
                    Text("\(itemCount)")
                        .font(.pakt(.hero).monospacedDigit())
                        .foregroundStyle(Color.paktForeground)
                        .minimumScaleFactor(0.6)
                    Text(itemCount == 1 ? "item" : "items")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .tracking(0.4)
                }
                .frame(width: 68)
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(box.boxType?.label ?? "No type")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    HStack(spacing: 4) {
                        Image(paktIcon: "map-pin")
                            .font(.system(size: 10))
                        Text(box.destinationRoom?.label ?? "No destination")
                    }
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)

                    if !box.tags.isEmpty {
                        FlowLayout(spacing: 4, lineSpacing: 4) {
                            ForEach(box.tags, id: \.self) { tag in
                                Text(tag.label)
                                    .font(.pakt(.small))
                                    .foregroundStyle(tag == .fragile ? Color.paktTrash : Color.paktMutedForeground)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(
                                            (tag == .fragile ? Color.paktTrash : Color.paktMutedForeground).opacity(0.14)
                                        )
                                    )
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(paktIcon: "more-vertical")
                            .foregroundStyle(Color.paktMutedForeground)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Image(paktIcon: "chevron-right")
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
    }

    private var itemCount: Int {
        (box.boxItems ?? [])
            .filter { $0.item?.deletedAt == nil }
            .reduce(0) { $0 + $1.quantity }
    }
}
