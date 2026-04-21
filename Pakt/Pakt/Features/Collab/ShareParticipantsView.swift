import CloudKit
import SwiftData
import SwiftUI

/// Full share management for a Move.
///
/// Owner sees: all participants with their role/status/permission, can change
/// each collaborator's permission, remove individual collaborators, or stop
/// sharing the move entirely.
///
/// Non-owners see: a read-only list of participants with a note that they
/// can leave the share via stop-sharing (which deletes their local copy).
/// (Non-owner leave is not yet wired — for now they just see the list.)
struct ShareParticipantsView: View {
    let move: Move

    @Environment(CloudKitCollab.self) private var collab
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var share: CKShare?
    @State private var isOwner = false
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var pendingRemove: CKShare.Participant?
    @State private var confirmingStopSharing = false
    @State private var mutating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                content
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
            .confirmationDialog(
                "Remove this collaborator?",
                isPresented: Binding(
                    get: { pendingRemove != nil },
                    set: { if !$0 { pendingRemove = nil } }
                ),
                presenting: pendingRemove
            ) { participant in
                Button("Remove", role: .destructive) {
                    Task { await removeParticipant(participant) }
                }
                Button("Cancel", role: .cancel) { pendingRemove = nil }
            } message: { _ in
                Text("They'll lose access to this move on their next sync.")
            }
            .confirmationDialog(
                "Stop sharing this move?",
                isPresented: $confirmingStopSharing,
                titleVisibility: .visible
            ) {
                Button("Stop sharing", role: .destructive) {
                    Task { await stopSharing() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All collaborators will lose access. Your move data stays on this device and in iCloud.")
            }
        }
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        if loading {
            ProgressView().tint(Color.paktPrimary)
        } else if let errorMessage {
            errorView(errorMessage)
        } else if let share {
            participantsList(for: share)
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: PaktSpace.s3) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(Color.paktMutedForeground)
            Text("No active share")
                .font(.pakt(.heading))
                .foregroundStyle(Color.paktForeground)
            Text("Create an invite code from the move menu to bring someone in.")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PaktSpace.s4)
        }
        .padding(PaktSpace.s6)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: PaktSpace.s3) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.paktDestructive)
            Text("Couldn't load collaborators")
                .font(.pakt(.heading))
                .foregroundStyle(Color.paktForeground)
            Text(message)
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PaktSpace.s4)
            PaktButton("Try again", size: .lg) {
                Task { await load() }
            }
        }
        .padding(PaktSpace.s6)
    }

    private func participantsList(for share: CKShare) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                ForEach(Array(share.participants.enumerated()), id: \.offset) { _, p in
                    ParticipantRow(
                        participant: p,
                        isOwner: isOwner,
                        isBusy: mutating,
                        onChangePermission: { newPermission in
                            Task { await updatePermission(for: p, to: newPermission, share: share) }
                        },
                        onRemove: { pendingRemove = p }
                    )
                }

                if isOwner {
                    Divider()
                        .background(Color.paktBorder)
                        .padding(.vertical, PaktSpace.s2)

                    PaktButton("Stop sharing this move", variant: .destructive, size: .lg) {
                        confirmingStopSharing = true
                    }
                    .disabled(mutating)
                    .padding(.horizontal, PaktSpace.s4)

                    Text("Deletes the share. Your data stays. Collaborators lose access on their next sync.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PaktSpace.s4)
                }
            }
            .padding(PaktSpace.s4)
        }
    }

    // MARK: - Actions

    private func load() async {
        loading = true
        errorMessage = nil
        let fetched = await collab.fetchOwnerShare(for: move)
        // If the share came back from the owner's private DB, the current user
        // owns it. The userRecordID-based check is a secondary confirmation —
        // but not required; the fetch path itself is owner-gated by CloudKit.
        isOwner = fetched != nil
        share = fetched
        loading = false
    }

    private func updatePermission(
        for participant: CKShare.Participant,
        to permission: CKShare.ParticipantPermission,
        share: CKShare
    ) async {
        mutating = true
        defer { mutating = false }
        do {
            try await collab.updatePermission(for: participant, to: permission, on: share)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeParticipant(_ participant: CKShare.Participant) async {
        pendingRemove = nil
        guard let share else { return }
        mutating = true
        defer { mutating = false }
        do {
            try await collab.removeParticipant(participant, from: share)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopSharing() async {
        confirmingStopSharing = false
        mutating = true
        defer { mutating = false }
        do {
            try await collab.stopSharing(move: move, context: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ParticipantRow: View {
    let participant: CKShare.Participant
    let isOwner: Bool
    let isBusy: Bool
    let onChangePermission: (CKShare.ParticipantPermission) -> Void
    let onRemove: () -> Void

    var body: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                HStack(spacing: PaktSpace.s3) {
                    ZStack {
                        Circle().fill(Color.paktPrimary.opacity(0.15))
                        Image(systemName: iconName)
                            .foregroundStyle(Color.paktPrimary)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.pakt(.bodyMedium))
                            .foregroundStyle(Color.paktForeground)
                        HStack(spacing: PaktSpace.s2) {
                            Text(roleLabel)
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                            if participant.role != .owner {
                                PaktBadge(statusLabel, tone: .secondary)
                            }
                        }
                    }
                    Spacer()
                }

                if canManage {
                    HStack {
                        Text("Permission")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                        Spacer()
                        Picker("", selection: permissionBinding) {
                            Text("Read only").tag(CKShare.ParticipantPermission.readOnly)
                            Text("Can edit").tag(CKShare.ParticipantPermission.readWrite)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                        .disabled(isBusy)
                    }
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove collaborator", systemImage: "person.crop.circle.badge.xmark")
                            .font(.pakt(.small))
                    }
                    .disabled(isBusy)
                }
            }
        }
    }

    /// We can only manage non-owners, and only if the viewer is the owner.
    private var canManage: Bool {
        isOwner && participant.role != .owner
    }

    private var permissionBinding: Binding<CKShare.ParticipantPermission> {
        Binding(
            get: { participant.permission == .readOnly ? .readOnly : .readWrite },
            set: { onChangePermission($0) }
        )
    }

    private var displayName: String {
        let nc = participant.userIdentity.nameComponents
        if let nc, let formatted = PersonNameComponentsFormatter().string(from: nc).nilIfEmpty {
            return formatted
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress {
            return email
        }
        return participant.role == .owner ? "You (owner)" : "Collaborator"
    }

    private var roleLabel: String {
        switch participant.role {
        case .owner: return "Owner"
        case .administrator: return "Admin"
        case .privateUser: return "Collaborator"
        case .publicUser: return "Public"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    private var iconName: String {
        participant.role == .owner ? "person.crop.circle.fill" : "person.crop.circle"
    }

    private var statusLabel: String {
        switch participant.acceptanceStatus {
        case .accepted: return "Active"
        case .pending:  return "Pending"
        case .removed:  return "Removed"
        case .unknown:  return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
