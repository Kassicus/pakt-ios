import SwiftData
import SwiftUI

struct DashboardView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @State private var exportedPDFURL: URL?
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s4) {
                header
                quickActions
                countsGrid
                predictionsCard
                Spacer(minLength: 80)
            }
            .padding(PaktSpace.s4)
        }
        .background(Color.paktBackground)
        .navigationTitle(move.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbar }
        .navigationDestination(for: Room.self) { room in
            RoomDetailView(room: room)
        }
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .navigationDestination(for: Box.self) { box in
            BoxDetailView(box: box)
        }
        .sheet(item: Binding(
            get: { exportedPDFURL.map(PDFShareItem.init) },
            set: { _ in exportedPDFURL = nil }
        )) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .alert("Couldn't export",
               isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
               )
        ) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Move status") {
                    ForEach(MoveStatus.allCases, id: \.self) { status in
                        Button {
                            move.status = status
                            move.updatedAt = Date()
                            try? context.save()
                        } label: {
                            HStack {
                                Text(statusLabel(status))
                                if status == move.status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Divider()
                Button {
                    exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("More actions")
            }
        }
    }

    private func exportPDF() {
        do {
            let url = try InventoryPDFRenderer.renderToTempFile(for: move)
            exportedPDFURL = url
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func statusLabel(_ s: MoveStatus) -> String {
        switch s {
        case .planning:  return "Planning"
        case .packing:   return "Packing"
        case .inTransit: return "In transit"
        case .unpacking: return "Unpacking"
        case .done:      return "Done"
        }
    }

    private var quickActions: some View {
        VStack(spacing: PaktSpace.s2) {
            NavigationLink {
                RoomListView(move: move)
            } label: {
                QuickActionCard(
                    icon: "package-open",
                    title: "Inventory",
                    subtitle: "Rooms, items, and photos"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                TriageDeckView(move: move)
            } label: {
                QuickActionCard(
                    icon: "shuffle",
                    title: "Triage",
                    subtitle: undecidedCount == 0
                        ? "Nothing undecided right now"
                        : "\(undecidedCount) item\(undecidedCount == 1 ? "" : "s") to decide"
                )
            }
            .buttonStyle(.plain)
            .disabled(undecidedCount == 0)
            .opacity(undecidedCount == 0 ? 0.5 : 1)

            NavigationLink {
                BoxesListView(move: move)
            } label: {
                QuickActionCard(
                    icon: "box",
                    title: "Boxes",
                    subtitle: liveBoxes.isEmpty
                        ? "Create your first box"
                        : "\(liveBoxes.count) box\(liveBoxes.count == 1 ? "" : "es") in play"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SearchView(move: move)
            } label: {
                QuickActionCard(
                    icon: "search",
                    title: "Search",
                    subtitle: "Find any item by name or room"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ChecklistView(move: move)
            } label: {
                QuickActionCard(
                    icon: "check-circle",
                    title: "Checklist",
                    subtitle: checklistSubtitle
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ScanRouterView(move: move)
            } label: {
                QuickActionCard(
                    icon: "scan-line",
                    title: "Scan",
                    subtitle: "Point the camera at a label"
                )
            }
            .buttonStyle(.plain)
            .disabled(liveBoxes.isEmpty)
            .opacity(liveBoxes.isEmpty ? 0.5 : 1)

            NavigationLink {
                LabelsView(move: move)
            } label: {
                QuickActionCard(
                    icon: "qr-code",
                    title: "Labels",
                    subtitle: liveBoxes.isEmpty
                        ? "Labels appear after you create boxes"
                        : "Preview, save, or share labels"
                )
            }
            .buttonStyle(.plain)
            .disabled(liveBoxes.isEmpty)
            .opacity(liveBoxes.isEmpty ? 0.5 : 1)
        }
    }

    private var undecidedCount: Int {
        liveItems.filter { $0.disposition == .undecided }.count
    }

    private var checklistSubtitle: String {
        let all = move.checklist ?? []
        let total = all.count
        let done = all.filter { $0.isDone }.count
        if total == 0 { return "No tasks yet" }
        let pending = total - done
        return pending == 0
            ? "All tasks done"
            : "\(pending) task\(pending == 1 ? "" : "s") pending"
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: PaktSpace.s2) {
            if let date = move.plannedMoveDate {
                Text("Moving \(date.formatted(date: .long, time: .omitted))")
                    .font(.pakt(.body))
                    .foregroundStyle(Color.paktMutedForeground)
            }
            if let origin = move.originAddress, !origin.isEmpty {
                Text("From \(origin)")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
            if let dest = move.destinationAddress, !dest.isEmpty {
                Text("To \(dest)")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
    }

    private var countsGrid: some View {
        let live = liveItems
        return LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: PaktSpace.s3) {
            StatCard(title: "Items",     value: "\(live.count)")
            StatCard(title: "Moving",    value: "\(live.filter { $0.disposition == .moving }.count)")
            StatCard(title: "Undecided", value: "\(live.filter { $0.disposition == .undecided }.count)")
            StatCard(title: "Boxes",     value: "\(liveBoxes.count)")
        }
    }

    private var predictionsCard: some View {
        let rec = truckRecommendation
        let counts = boxCounts
        return PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                Text("Predicted packing").font(.pakt(.heading))
                if counts.totalBoxCount == 0 {
                    Text("Add items to see predicted box counts.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                } else {
                    ForEach(RecommendedBoxType.allCases.filter { $0 != .none }, id: \.self) { type in
                        let n = counts.boxesByType[type] ?? 0
                        if n > 0 {
                            HStack {
                                Text(label(for: type)).font(.pakt(.body))
                                    .foregroundStyle(Color.paktForeground)
                                Spacer()
                                PaktBadge("\(n)", tone: .secondary)
                            }
                        }
                    }
                }

                Divider().background(Color.paktBorder)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Truck size").font(.pakt(.bodyMedium))
                            .foregroundStyle(Color.paktForeground)
                        Spacer()
                        PaktBadge(rec.size.rawValue, tone: .default)
                    }
                    Text(rec.note)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                    if rec.heavyItemCount > 0 {
                        Text("\(rec.heavyItemCount) heavy item\(rec.heavyItemCount == 1 ? "" : "s") — plan for movers.")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktDestructive)
                    }
                }
            }
        }
    }

    // MARK: - Data helpers

    private var liveItems: [Item] {
        (move.items ?? []).filter { $0.deletedAt == nil }
    }

    private var liveBoxes: [Box] {
        (move.boxes ?? []).filter { $0.deletedAt == nil }
    }

    private var predictionInputs: [Predictions.PredictionItem] {
        liveItems.map { item in
            let category = ItemCategories.lookup(item.categoryId)
            return Predictions.PredictionItem(
                categoryId: item.categoryId,
                quantity: item.quantity,
                volumeCuFt: item.volumeCuFtOverride ?? category?.volumeCuFtPerItem ?? 0.5,
                weightLbs: item.weightLbsOverride ?? category?.weightLbsPerItem ?? 5,
                recommendedBoxType: category?.recommendedBoxType ?? .medium,
                disposition: item.disposition
            )
        }
    }

    private var boxCounts: Predictions.BoxCountResult {
        Predictions.predictBoxCounts(items: predictionInputs)
    }

    private var truckRecommendation: Predictions.TruckRecommendation {
        Predictions.recommendTruck(items: predictionInputs)
    }

    private func label(for type: RecommendedBoxType) -> String {
        switch type {
        case .small:    return "Small"
        case .medium:   return "Medium"
        case .large:    return "Large"
        case .dishPack: return "Dish pack"
        case .wardrobe: return "Wardrobe"
        case .tote:     return "Tote"
        case .none:     return "Loose"
        }
    }
}

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        PaktCard {
            HStack {
                Image(paktIcon: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.paktPrimary)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: PaktRadius.md)
                        .fill(Color.paktPrimary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    Text(subtitle)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                Spacer()
                Image(paktIcon: "chevron-right")
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                Text(value).font(.pakt(.title))
                    .foregroundStyle(Color.paktForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
