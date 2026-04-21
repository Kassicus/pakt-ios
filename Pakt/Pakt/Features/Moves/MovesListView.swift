import SwiftData
import SwiftUI

struct MovesListView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Move> { $0.deletedAt == nil },
        sort: \Move.updatedAt,
        order: .reverse
    ) private var moves: [Move]

    @State private var showingNewMove = false
    @State private var showingSettings = false
    @State private var showingAcceptInvite = false
    @State private var pendingDelete: Move?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                                .accessibilityLabel("Settings")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { showingNewMove = true } label: {
                                Label("New move", systemImage: "plus")
                            }
                            Button { showingAcceptInvite = true } label: {
                                Label("Accept invite", systemImage: "envelope.open")
                            }
                        } label: {
                            Image(paktIcon: "plus")
                                .accessibilityLabel("Add")
                        }
                    }
                }
        }
        .sheet(isPresented: $showingNewMove) {
            NewMoveView().environment(auth)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environment(auth)
        }
        .sheet(isPresented: $showingAcceptInvite) {
            AcceptInviteView().environment(auth)
        }
        .confirmationDialog(
            "Remove this move?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let move = pendingDelete { performDelete(move) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Rooms, items, photos, and boxes stay attached but are hidden. You can undo right after.")
        }
    }

    @ViewBuilder private var content: some View {
        if moves.isEmpty {
            PaktScreen(accent: .paktPrimary) {
                PaktHeroHeader(
                    eyebrow: "Pakt",
                    title: "Your moves",
                    subtitle: "No moves yet.",
                    accent: .paktPrimary,
                    titleStyle: .hero
                )
                PaktEmptyState(
                    icon: "package-open",
                    title: "Start your first move",
                    message: "Track inventory, box contents, and everything else from here.",
                    primary: .init("Create a move") { showingNewMove = true },
                    secondary: .init("Accept an invite") { showingAcceptInvite = true }
                )
            }
        } else {
            PaktScreen(accent: .paktPrimary) {
                PaktHeroHeader(
                    eyebrow: "Pakt",
                    title: "Your moves",
                    subtitle: "\(moves.count) active",
                    accent: .paktPrimary,
                    titleStyle: .hero
                )
                VStack(spacing: PaktSpace.s2) {
                    ForEach(moves) { move in
                        NavigationLink(value: move) {
                            MoveRow(move: move, onDelete: { pendingDelete = move })
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { pendingDelete = move } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Move.self) { move in
                DashboardView(move: move)
            }
        }
    }

    private func performDelete(_ move: Move) {
        let now = Date()
        move.deletedAt = now
        move.updatedAt = now
        try? context.save()
        DeletionTipEvents.userDidSwipeToDelete()
        UndoToastCenter.shared.show(message: "\"\(move.name)\" removed") {
            move.deletedAt = nil
            move.updatedAt = Date()
            try? context.save()
        }
    }
}

private struct MoveRow: View {
    let move: Move
    let onDelete: () -> Void

    var body: some View {
        PaktSurface(accent: accent, padding: PaktSpace.s3) {
            HStack(alignment: .top, spacing: PaktSpace.s3) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 10, height: 2)
                            .clipShape(Capsule())
                        Text(statusLabel.uppercased())
                            .font(.pakt(.small))
                            .tracking(1.0)
                            .foregroundStyle(accent)
                    }
                    Text(move.name)
                        .font(.pakt(.heading))
                        .foregroundStyle(Color.paktForeground)
                    HStack(spacing: 6) {
                        if let date = move.plannedMoveDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                        if let dest = move.destinationAddress, !dest.isEmpty {
                            Text("→ \(dest)")
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if move.isShared {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 9))
                            Text("Shared")
                                .font(.pakt(.small))
                                .tracking(0.4)
                        }
                        .foregroundStyle(Color.paktPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.paktPrimary.opacity(0.14)))
                    }
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(paktIcon: "more-vertical")
                            .foregroundStyle(Color.paktMutedForeground)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var accent: Color {
        switch move.status {
        case .planning:  return .paktPrimary
        case .packing:   return .paktDonate
        case .inTransit: return .paktMoving
        case .unpacking: return .paktStorage
        case .done:      return .paktMutedForeground
        }
    }

    private var statusLabel: String {
        switch move.status {
        case .planning:  return "Planning"
        case .packing:   return "Packing"
        case .inTransit: return "In transit"
        case .unpacking: return "Unpacking"
        case .done:      return "Done"
        }
    }
}
