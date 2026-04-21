import SwiftData
import SwiftUI

struct DashboardView: View {
    let move: Move

    @Environment(AuthStore.self) private var auth
    @Environment(CloudKitSyncEngine.self) private var syncEngine
    @Environment(\.modelContext) private var context
    @State private var exportedPDFURL: URL?
    @State private var exportError: String?
    @State private var showingInvite = false
    @State private var showingInviteSignInPromo = false
    @State private var showingParticipants = false

    var body: some View {
        PaktScreen(accent: .paktPrimary) {
            heroHeader
            collabBanner
            statsStrip
            quickActions
            predictionsCard
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task(id: move.id) {
            // Pull the latest state for this shared Move whenever the user
            // lands here. Keeps the Dashboard feeling fresh even if a push
            // notification was dropped.
            if move.isShared {
                await syncEngine.pullMove(move)
            }
        }
        .sheet(item: Binding(
            get: { exportedPDFURL.map(PDFShareItem.init) },
            set: { _ in exportedPDFURL = nil }
        )) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .sheet(isPresented: $showingInvite) {
            InviteMoveView(move: move)
                .environment(auth)
        }
        .sheet(isPresented: $showingInviteSignInPromo) {
            SignInPromoView(context: .invite) {
                showingInviteSignInPromo = false
                showingInvite = true
            }
            .environment(auth)
        }
        .sheet(isPresented: $showingParticipants) {
            ShareParticipantsView(move: move)
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

    @ViewBuilder private var collabBanner: some View {
        if move.isShared {
            Button {
                showingParticipants = true
            } label: {
                PaktSurface(accent: .paktAccent, padding: PaktSpace.s3) {
                    HStack(spacing: PaktSpace.s3) {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(Color.paktPrimary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.paktPrimary.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shared move")
                                .font(.pakt(.bodyMedium))
                                .foregroundStyle(Color.paktForeground)
                            Text("Tap to view collaborators")
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                        Spacer()
                        Image(paktIcon: "chevron-right")
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var heroHeader: some View {
        PaktHeroHeader(
            eyebrow: statusLabel(move.status),
            title: move.name,
            subtitle: heroSubtitle,
            accent: .paktPrimary,
            titleStyle: .hero
        )
    }

    private var heroSubtitle: String {
        var parts: [String] = []
        if let date = move.plannedMoveDate {
            parts.append("Moving \(date.formatted(date: .abbreviated, time: .omitted))")
        }
        if let dest = move.destinationAddress, !dest.isEmpty {
            parts.append("→ \(dest)")
        }
        if parts.isEmpty { parts.append("Draft move") }
        return parts.joined(separator: "  ·  ")
    }

    private var statsStrip: some View {
        let live = liveItems
        let movingCount = live.filter { $0.disposition == .moving }.count
        let undecidedCount = live.filter { $0.disposition == .undecided }.count
        let boxCount = liveBoxes.count
        return PaktSurface(accent: .paktPrimary, padding: PaktSpace.s3) {
            HStack(alignment: .top, spacing: 0) {
                statTile(label: "Items", value: live.count, tint: .paktPrimary)
                divider
                statTile(label: "Moving", value: movingCount, tint: .paktMoving)
                divider
                statTile(label: "Undecided", value: undecidedCount, tint: .paktUndecided)
                divider
                statTile(label: "Boxes", value: boxCount, tint: .paktStorage)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.paktBorder)
            .frame(width: 1, height: 36)
            .padding(.vertical, 4)
    }

    private func statTile(label: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.pakt(.title).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(value)))
                .animation(PaktMotion.standard, value: value)
            Text(label.uppercased())
                .font(.pakt(.small))
                .tracking(0.6)
                .foregroundStyle(Color.paktMutedForeground)
        }
        .frame(maxWidth: .infinity)
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
                    if case .signedIn = auth.state {
                        showingInvite = true
                    } else {
                        showingInviteSignInPromo = true
                    }
                } label: {
                    Label("Invite collaborator", systemImage: "person.badge.plus")
                }
                if move.isShared {
                    Button {
                        showingParticipants = true
                    } label: {
                        Label("Collaborators", systemImage: "person.2")
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
        let items = liveItems
        let itemCount = items.count
        let undecided = items.filter { $0.disposition == .undecided }.count
        let boxCount = liveBoxes.count
        let pendingTasks = (move.checklist ?? []).filter { !$0.isDone }.count

        return VStack(alignment: .leading, spacing: PaktSpace.s2) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.paktPrimary)
                    .frame(width: 14, height: 2)
                    .clipShape(Capsule())
                Text("QUICK ACTIONS")
                    .font(.pakt(.small))
                    .tracking(1.2)
                    .foregroundStyle(Color.paktPrimary)
            }

            LazyVGrid(columns: [.init(.flexible(), spacing: PaktSpace.s2), .init(.flexible(), spacing: PaktSpace.s2)], spacing: PaktSpace.s2) {
                NavigationLink { RoomListView(move: move) } label: {
                    QuickActionTile(icon: "package-open", title: "Inventory",
                                    subtitle: "\(itemCount) item\(itemCount == 1 ? "" : "s")",
                                    accent: .paktPrimary,
                                    count: itemCount)
                }
                .buttonStyle(.plain)

                NavigationLink { TriageDeckView(move: move) } label: {
                    QuickActionTile(icon: "shuffle", title: "Triage",
                                    subtitle: undecided == 0 ? "All sorted" : "\(undecided) to decide",
                                    accent: .paktDonate,
                                    count: undecided > 0 ? undecided : nil)
                }
                .buttonStyle(.plain)
                .disabled(undecided == 0)
                .opacity(undecided == 0 ? 0.5 : 1)

                NavigationLink { BoxesListView(move: move) } label: {
                    QuickActionTile(icon: "box", title: "Boxes",
                                    subtitle: liveBoxes.isEmpty ? "Create your first" : "\(boxCount) in play",
                                    accent: .paktStorage,
                                    count: boxCount > 0 ? boxCount : nil)
                }
                .buttonStyle(.plain)

                NavigationLink { ChecklistView(move: move) } label: {
                    QuickActionTile(icon: "check-circle", title: "Checklist",
                                    subtitle: checklistSubtitle,
                                    accent: .paktMoving,
                                    count: pendingTasks > 0 ? pendingTasks : nil)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: PaktSpace.s2) {
                NavigationLink { SearchView(move: move) } label: {
                    QuickActionBar(icon: "search", title: "Search", subtitle: "Find any item", accent: .paktMutedForeground)
                }
                .buttonStyle(.plain)

                NavigationLink { ScanRouterView(move: move) } label: {
                    QuickActionBar(icon: "scan-line", title: "Scan", subtitle: "Point the camera", accent: .paktSold)
                }
                .buttonStyle(.plain)
                .disabled(liveBoxes.isEmpty)
                .opacity(liveBoxes.isEmpty ? 0.5 : 1)
            }

            NavigationLink { LabelsView(move: move) } label: {
                QuickActionBar(
                    icon: "qr-code",
                    title: "Labels",
                    subtitle: liveBoxes.isEmpty ? "After you create boxes" : "Preview, save, share",
                    accent: .paktPrimary,
                    count: liveBoxes.isEmpty ? nil : boxCount
                )
            }
            .buttonStyle(.plain)
            .disabled(liveBoxes.isEmpty)
            .opacity(liveBoxes.isEmpty ? 0.5 : 1)
        }
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

    private var predictionsCard: some View {
        let rec = truckRecommendation
        let counts = boxCounts
        return PaktSurface(title: "Predicted packing", icon: "truck", accent: .paktMoving) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                if counts.totalBoxCount == 0 {
                    Text("Add items to see predicted box counts.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                } else {
                    PaktFieldStack {
                        ForEach(RecommendedBoxType.allCases.filter { $0 != .none }, id: \.self) { type in
                            let n = counts.boxesByType[type] ?? 0
                            if n > 0 {
                                PaktField(label(for: type)) {
                                    Text("\(n)")
                                        .font(.pakt(.bodyMedium).monospacedDigit())
                                        .foregroundStyle(Color.paktPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.paktPrimary.opacity(0.14)))
                                }
                            }
                        }
                    }
                }

                Rectangle().fill(Color.paktBorder.opacity(0.6)).frame(height: 1)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Truck size").font(.pakt(.bodyMedium))
                            .foregroundStyle(Color.paktForeground)
                        Spacer()
                        Text(rec.size.rawValue)
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktPrimaryForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.paktPrimary))
                    }
                    Text(rec.note)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                    if rec.heavyItemCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("\(rec.heavyItemCount) heavy item\(rec.heavyItemCount == 1 ? "" : "s") — plan for movers.")
                        }
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

private struct QuickActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    var count: Int? = nil

    var body: some View {
        PaktSurface(accent: accent, padding: PaktSpace.s3) {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack(alignment: .top) {
                    Image(paktIcon: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                                .fill(accent.opacity(0.14))
                        )
                    Spacer()
                    if let count {
                        Text("\(count)")
                            .font(.pakt(.bodyMedium).monospacedDigit())
                            .foregroundStyle(accent)
                            .contentTransition(.numericText(value: Double(count)))
                            .animation(PaktMotion.standard, value: count)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    Text(subtitle)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
    }
}

private struct QuickActionBar: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    var count: Int? = nil

    var body: some View {
        PaktSurface(accent: accent, padding: PaktSpace.s3) {
            HStack(spacing: PaktSpace.s3) {
                Image(paktIcon: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                            .fill(accent.opacity(0.14))
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    Text(subtitle)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.pakt(.small).monospacedDigit())
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.14)))
                }
                Image(paktIcon: "chevron-right")
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
    }
}
