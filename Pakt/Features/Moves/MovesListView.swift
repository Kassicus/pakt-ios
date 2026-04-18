import PaktCore
import SwiftUI

struct MovesListView: View {
    @Environment(MovesStore.self) private var store
    @Environment(AuthStore.self) private var auth

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Moves")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task { await auth.signOut() }
                            } label: {
                                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(paktIcon: "user")
                        }
                    }
                }
                .task { await store.load() }
                .refreshable { await store.refresh() }
                .background(Color.paktBackground)
        }
    }

    @ViewBuilder private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: PaktSpace.s3) {
                Text("Couldn't load moves").font(.pakt(.heading))
                Text(message).font(.pakt(.small)).foregroundStyle(Color.paktMutedForeground)
                PaktButton("Retry") { Task { await store.refresh() } }
            }
            .padding(PaktSpace.s6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let entries):
            if entries.isEmpty {
                EmptyMovesView()
            } else {
                List(entries) { entry in
                    MoveRow(entry: entry)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct MoveRow: View {
    let entry: MoveListEntry

    var body: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                HStack {
                    Text(entry.move.name).font(.pakt(.heading))
                        .foregroundStyle(Color.paktForeground)
                    Spacer()
                    PaktBadge(roleLabel, tone: roleTone)
                }
                if let date = entry.move.plannedMoveDate, !date.isEmpty {
                    Text("Moving \(date)")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
                HStack(spacing: 8) {
                    PaktBadge(statusLabel, tone: .secondary)
                    if let dest = entry.move.destinationAddress, !dest.isEmpty {
                        Text("→ \(dest)")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var roleLabel: String {
        switch entry.role {
        case .owner:  return "Owner"
        case .editor: return "Editor"
        case .helper: return "Helper"
        }
    }

    private var roleTone: PaktBadgeTone {
        switch entry.role {
        case .owner:  return .default
        case .editor: return .secondary
        case .helper: return .outline
        }
    }

    private var statusLabel: String {
        switch entry.move.status {
        case .planning:   return "Planning"
        case .packing:    return "Packing"
        case .inTransit:  return "In transit"
        case .unpacking:  return "Unpacking"
        case .done:       return "Done"
        }
    }
}

private struct EmptyMovesView: View {
    var body: some View {
        VStack(spacing: PaktSpace.s3) {
            Image(paktIcon: "package-open")
                .font(.system(size: 44))
                .foregroundStyle(Color.paktMutedForeground)
            Text("No moves yet").font(.pakt(.heading))
            Text("Create your first move on the web to get started.\nNative move creation ships in M2.")
                .multilineTextAlignment(.center)
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
        }
        .padding(PaktSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
