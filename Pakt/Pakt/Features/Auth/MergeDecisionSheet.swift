import SwiftData
import SwiftUI

/// Shown when a guest user signs in and we detect Pakt data on the same Apple
/// ID in iCloud. The user chooses between keeping their local data (letting
/// remote merge in alongside) or wiping local and trusting iCloud.
struct MergeDecisionSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var confirmingStartFresh = false
    @State private var exportedPDFURL: URL?

    @Query private var moves: [Move]

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(spacing: PaktSpace.s5) {
                Spacer()

                VStack(spacing: PaktSpace.s3) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.paktPrimary)

                    Text("You have moves on this device and in iCloud")
                        .font(.pakt(.title))
                        .foregroundStyle(Color.paktForeground)
                        .multilineTextAlignment(.center)

                    Text("This iPhone has \(moves.count) local move\(moves.count == 1 ? "" : "s") from guest mode, and your Apple ID already has Pakt data in iCloud.")
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktMutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PaktSpace.s4)
                }

                Spacer()

                VStack(spacing: PaktSpace.s2) {
                    PaktButton("Keep my local moves", size: .lg) {
                        auth.resumeAfterMergeDecision(keepLocal: true, context: context)
                        dismiss()
                    }
                    Text("Local moves stay. iCloud data will also sync in — you may see duplicates to clean up.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .multilineTextAlignment(.center)

                    PaktButton("Start fresh from iCloud", variant: .destructive, size: .lg) {
                        confirmingStartFresh = true
                    }
                    .padding(.top, PaktSpace.s2)
                    Text("Deletes your \(moves.count) local move\(moves.count == 1 ? "" : "s") and restores from iCloud. This can't be undone.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, PaktSpace.s5)
            .padding(.bottom, PaktSpace.s6)
        }
        .interactiveDismissDisabled(true)
        .confirmationDialog(
            "Delete local moves?",
            isPresented: $confirmingStartFresh,
            titleVisibility: .visible
        ) {
            if !moves.isEmpty {
                Button("Export PDF first") {
                    exportFirstMovePDF()
                }
            }
            Button("Delete and continue", role: .destructive) {
                auth.resumeAfterMergeDecision(keepLocal: false, context: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your \(moves.count) local move\(moves.count == 1 ? "" : "s") will be removed from this device. iCloud will re-sync from your Apple ID.")
        }
        .sheet(item: Binding(
            get: { exportedPDFURL.map(PDFShareItem.init) },
            set: { _ in exportedPDFURL = nil }
        )) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func exportFirstMovePDF() {
        guard let move = moves.first else { return }
        if let url = try? InventoryPDFRenderer.renderToTempFile(for: move) {
            exportedPDFURL = url
        }
    }
}
