import CloudKit
import SwiftData
import SwiftUI

/// Inviter-side UI. Given a Move, wraps it in a CKShare (if not already) and
/// shows a human-friendly short code for the inviter to share however they
/// like.
///
/// Only presented when the current user is signed in with Apple — callers
/// gate this; this view assumes `.signedIn`.
struct InviteMoveView: View {
    let move: Move

    @Environment(AuthStore.self) private var auth
    @Environment(CloudKitCollab.self) private var collab
    @Environment(InviteCodeServiceHolder.self) private var inviteCodeHolder
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .preparing
    @State private var inviteCode: String?
    @State private var expiresAt: Date?
    @State private var errorMessage: String?
    @State private var showingShareSheet = false

    @Query private var users: [User]

    enum Phase {
        case preparing
        case ready
        case failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                content
                    .padding(.horizontal, PaktSpace.s5)
            }
            .navigationTitle("Invite to \(move.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
        .task { await prepareInvite() }
        .sheet(isPresented: $showingShareSheet) {
            if let code = inviteCode {
                ShareSheet(items: [inviteShareText(code: code)])
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .preparing: preparingView
        case .ready:     readyView
        case .failed:    failedView
        }
    }

    private var preparingView: some View {
        VStack(spacing: PaktSpace.s4) {
            Spacer()
            ProgressView().tint(Color.paktPrimary)
            Text("Preparing your invite…")
                .font(.pakt(.body))
                .foregroundStyle(Color.paktMutedForeground)
            Spacer()
        }
    }

    private var readyView: some View {
        VStack(spacing: PaktSpace.s5) {
            Spacer()

            VStack(spacing: PaktSpace.s3) {
                Text("Share this code")
                    .font(.pakt(.heading))
                    .foregroundStyle(Color.paktMutedForeground)

                Text(inviteCode ?? "")
                    .font(.system(size: 40, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.paktForeground)
                    .kerning(2)
                    .padding(.vertical, PaktSpace.s3)
                    .padding(.horizontal, PaktSpace.s5)
                    .background(
                        RoundedRectangle(cornerRadius: PaktRadius.lg)
                            .fill(Color.paktPrimary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: PaktRadius.lg)
                                    .strokeBorder(Color.paktPrimary.opacity(0.25))
                            )
                    )

                if let expiresAt {
                    Text("Expires \(expiresAt.formatted(date: .omitted, time: .shortened))")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }

            Spacer()

            VStack(spacing: PaktSpace.s2) {
                PaktButton("Copy code", size: .lg) {
                    if let code = inviteCode {
                        UIPasteboard.general.string = code
                    }
                }
                PaktButton("Share…", variant: .outline, size: .lg) {
                    showingShareSheet = true
                }
            }

            Text("The recipient enters this code in Pakt under \"Accept invite\". They'll need to sign in with their own Apple ID to join.")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.top, PaktSpace.s2)
        }
        .padding(.bottom, PaktSpace.s6)
    }

    private var failedView: some View {
        VStack(spacing: PaktSpace.s3) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.paktDestructive)
            Text("Couldn't prepare this invite")
                .font(.pakt(.heading))
                .foregroundStyle(Color.paktForeground)
            if let msg = errorMessage {
                Text(msg)
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
            }
            PaktButton("Try again", size: .lg) {
                phase = .preparing
                Task { await prepareInvite() }
            }
            .padding(.top, PaktSpace.s2)
            Spacer()
        }
    }

    // MARK: - Actions

    private func prepareInvite() async {
        guard case .signedIn(let appleUserId, _) = auth.state else {
            errorMessage = "Sign in first."
            phase = .failed
            return
        }

        let inviterName = users.first { $0.appleUserId == appleUserId }?.displayName
            ?? users.first { $0.appleUserId == appleUserId }?.email
            ?? "A Pakt user"

        do {
            let shareResult = try await collab.share(move: move, context: context)
            let invite = try await inviteCodeHolder.service.create(
                shareURL: shareResult.shareURL,
                moveName: shareResult.moveName,
                inviterName: inviterName
            )
            inviteCode = invite.code
            expiresAt = invite.expiresAt
            phase = .ready

            // Sweep expired codes opportunistically.
            Task { await inviteCodeHolder.service.sweepExpired() }
        } catch let err as LocalizedError {
            errorMessage = err.errorDescription
            phase = .failed
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    private func inviteShareText(code: String) -> String {
        "Join my move on Pakt. Open the app, tap Accept Invite, and enter code \(code)."
    }
}
