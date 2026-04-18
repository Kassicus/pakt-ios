import PaktCore
import SwiftData
import SwiftUI

struct MovesListView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Query(sort: \Move.updatedAt, order: .reverse) private var moves: [Move]

    @State private var showingNewMove = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Moves")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button(role: .destructive, action: auth.signOut) {
                                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(paktIcon: "user")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingNewMove = true } label: {
                            Image(paktIcon: "plus")
                        }
                    }
                }
                .background(Color.paktBackground)
        }
        .sheet(isPresented: $showingNewMove) {
            NewMoveView().environment(auth)
        }
    }

    @ViewBuilder private var content: some View {
        if moves.isEmpty {
            EmptyMovesView { showingNewMove = true }
        } else {
            List {
                ForEach(moves) { move in
                    NavigationLink(value: move) {
                        MoveRow(move: move)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(moves[index])
                    }
                    try? context.save()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationDestination(for: Move.self) { move in
                DashboardView(move: move)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(PaktSpace.s6)
    }
}
