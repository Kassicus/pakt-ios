import SwiftData
import SwiftUI

struct MovesListView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Query(sort: \Move.updatedAt, order: .reverse) private var moves: [Move]

    @State private var showingNewMove = false
    @State private var showingSettings = false
    @State private var showingAcceptInvite = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Moves")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                                .accessibilityLabel("Settings")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingNewMove = true
                            } label: {
                                Label("New move", systemImage: "plus")
                            }
                            Button {
                                showingAcceptInvite = true
                            } label: {
                                Label("Accept invite", systemImage: "envelope.open")
                            }
                        } label: {
                            Image(paktIcon: "plus")
                                .accessibilityLabel("Add")
                        }
                    }
                }
                .background(Color.paktBackground)
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
    }

    @State private var pendingDeletion: IndexSet?

    @ViewBuilder private var content: some View {
        if moves.isEmpty {
            EmptyMovesView(
                onCreate: { showingNewMove = true },
                onAcceptInvite: { showingAcceptInvite = true }
            )
        } else {
            List {
                ForEach(moves) { move in
                    NavigationLink(value: move) {
                        MoveRow(move: move)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityHint("Opens \(move.name) dashboard")
                }
                .onDelete { offsets in pendingDeletion = offsets }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationDestination(for: Move.self) { move in
                DashboardView(move: move)
            }
            .confirmationDialog(
                "Delete this move?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    if let offsets = pendingDeletion {
                        for index in offsets { context.delete(moves[index]) }
                        try? context.save()
                    }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("All rooms, items, photos, and boxes for this move will be removed from every signed-in device.")
            }
        }
    }
}

private struct MoveRow: View {
    let move: Move

    var body: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack {
                    Text(move.name).font(.pakt(.heading))
                        .foregroundStyle(Color.paktForeground)
                    Spacer()
                    if move.isShared {
                        PaktBadge("Shared", tone: .default)
                    }
                    PaktBadge(statusLabel, tone: .secondary)
                }
                if let date = move.plannedMoveDate {
                    Text("Moving \(date.formatted(date: .abbreviated, time: .omitted))")
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
        .padding(.vertical, 4)
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

private struct EmptyMovesView: View {
    let onCreate: () -> Void
    let onAcceptInvite: () -> Void

    var body: some View {
        VStack(spacing: PaktSpace.s4) {
            Image(paktIcon: "package-open")
                .font(.system(size: 48))
                .foregroundStyle(Color.paktMutedForeground)
            Text("Start your first move").font(.pakt(.heading))
            Text("Track inventory, box contents, and everything else from here.")
                .multilineTextAlignment(.center)
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .padding(.horizontal, PaktSpace.s6)
            PaktButton("Create a move", size: .lg, action: onCreate)
                .padding(.top, PaktSpace.s2)
            PaktButton("Accept an invite", variant: .ghost, size: .lg, action: onAcceptInvite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PaktSpace.s6)
    }
}
