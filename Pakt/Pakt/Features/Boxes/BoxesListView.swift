import SwiftData
import SwiftUI

struct BoxesListView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @State private var showingNewBox = false
    @State private var showingBoxTypes = false

    var body: some View {
        Group {
            if liveBoxes.isEmpty {
                EmptyBoxesView(canCreate: !boxTypesAvailable.isEmpty) {
                    showingNewBox = true
                } onManageTypes: {
                    showingBoxTypes = true
                }
            } else {
                List {
                    ForEach(statusGroups, id: \.status) { group in
                        Section(header: sectionHeader(group)) {
                            ForEach(group.boxes, id: \.id) { box in
                                NavigationLink {
                                    BoxDetailView(box: box)
                                } label: {
                                    BoxRow(box: box)
                                }
                                .listRowBackground(Color.paktCard)
                            }
                            .onDelete { offsets in
                                softDelete(group: group, at: offsets)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.paktBackground)
            }
        }
        .navigationTitle("Boxes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingNewBox = true
                    } label: { Label("New box", systemImage: "plus") }
                    Button {
                        showingBoxTypes = true
                    } label: { Label("Box types", systemImage: "cube") }
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

    @ViewBuilder private func sectionHeader(_ group: StatusGroup) -> some View {
        HStack(spacing: PaktSpace.s2) {
            PaktBadge(group.status.label, tone: group.status.tone)
            Text("\(group.boxes.count)")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
        }
    }

    private func softDelete(group: StatusGroup, at offsets: IndexSet) {
        for index in offsets {
            group.boxes[index].deletedAt = Date()
            group.boxes[index].updatedAt = Date()
        }
        try? context.save()
    }
}

// MARK: - Rows

private struct BoxRow: View {
    let box: Box

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            Text(box.shortCode)
                .font(.pakt(.mono).monospaced())
                .foregroundStyle(Color.paktForeground)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: PaktRadius.md)
                    .fill(Color.paktMuted))

            VStack(alignment: .leading, spacing: 2) {
                Text(box.boxType?.label ?? "No type")
                    .font(.pakt(.bodyMedium))
                    .foregroundStyle(Color.paktForeground)
                HStack(spacing: 4) {
                    if let dest = box.destinationRoom {
                        Image(paktIcon: "map-pin")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.paktMutedForeground)
                        Text(dest.label)
                    } else {
                        Text("No destination yet")
                    }
                }
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(box.tags, id: \.self) { tag in
                        PaktBadge(tag.label, tone: tag == .fragile ? .destructive : .outline)
                    }
                }
                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
        .padding(.vertical, 4)
    }

    private var itemCount: Int {
        (box.boxItems ?? []).reduce(0) { $0 + $1.quantity }
    }
}

private struct EmptyBoxesView: View {
    let canCreate: Bool
    let onCreate: () -> Void
    let onManageTypes: () -> Void

    var body: some View {
        VStack(spacing: PaktSpace.s4) {
            Image(paktIcon: "box")
                .font(.system(size: 48))
                .foregroundStyle(Color.paktMutedForeground)
            Text("No boxes yet").font(.pakt(.heading))
            Text("Create a box, then add items to it as you pack.")
                .multilineTextAlignment(.center)
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .padding(.horizontal, PaktSpace.s6)
            if canCreate {
                PaktButton("Create a box", size: .lg, action: onCreate)
            } else {
                VStack(spacing: 8) {
                    Text("Add a box type first.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                    PaktButton("Manage box types", action: onManageTypes)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PaktSpace.s6)
        .background(Color.paktBackground)
    }
}
