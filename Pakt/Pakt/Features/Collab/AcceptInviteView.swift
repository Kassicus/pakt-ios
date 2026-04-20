import SwiftData
import SwiftUI

/// Invitee-side UI. User enters a short code; we resolve it to a CKShare
/// URL via the public DB, show a confirmation preview, then accept and
/// materialize the shared Move into the local store.
///
/// Requires the user to be signed in with Apple — if they're a guest, we
/// present SignInPromoView first.
struct AcceptInviteView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(CloudKitCollab.self) private var collab
    @Environment(CloudKitSyncEngine.self) private var syncEngine
    @Environment(InviteCodeServiceHolder.self) private var inviteCodeHolder
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private static let codePrefix = "PAKT-"

    @State private var phase: Phase = .enterCode
    @State private var rawCode: String = codePrefix
    @State private var resolvedInvite: InviteCodeService.InviteRecord?
    @State private var errorMessage: String?
    @State private var showingSignInPromo = false

    enum Phase {
        case enterCode
        case lookingUp
        case confirm
        case accepting
        case accepted
        case failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                content
                    .padding(.horizontal, PaktSpace.s5)
            }
            .navigationTitle("Accept invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
        .sheet(isPresented: $showingSignInPromo) {
            SignInPromoView(context: .accept) {
                showingSignInPromo = false
                Task { await performAccept() }
            }
            .environment(auth)
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .enterCode: enterCodeView
        case .lookingUp: lookingUpView
        case .confirm:   confirmView
        case .accepting: acceptingView
        case .accepted:  acceptedView
        case .failed:    failedView
        }
    }

    private var enterCodeView: some View {
        VStack(spacing: PaktSpace.s4) {
            Spacer()

            VStack(spacing: PaktSpace.s2) {
                Text("Enter your invite code")
                    .font(.pakt(.title))
                    .foregroundStyle(Color.paktForeground)
                    .multilineTextAlignment(.center)
                Text("Codes look like PAKT-8F3Q. Your co-planner can see it on their device.")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
            }

            TextField("PAKT-XXXX", text: $rawCode)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(PaktSpace.s3)
                .background(
                    RoundedRectangle(cornerRadius: PaktRadius.lg)
                        .fill(Color.paktSecondary.opacity(0.35))
                )
                .padding(.horizontal, PaktSpace.s5)
                .onChange(of: rawCode) { _, newValue in
                    // Keep the PAKT- prefix locked in place so the user only
                    // has to type the 4-character body. Uppercase as they go.
                    let upper = newValue.uppercased()
                    if !upper.hasPrefix(Self.codePrefix) {
                        // User deleted into the prefix; restore it and keep
                        // whatever body chars they had left.
                        let body = upper.replacingOccurrences(of: Self.codePrefix, with: "")
                        rawCode = Self.codePrefix + body
                    } else if upper != newValue {
                        rawCode = upper
                    }
                }

            Spacer()

            PaktButton("Look up", size: .lg) {
                Task { await lookup() }
            }
            .disabled(normalizedCodeBody.count < 4)
            .opacity(normalizedCodeBody.count < 4 ? 0.5 : 1)

            Text("Joining a shared move requires your Apple ID.")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.bottom, PaktSpace.s6)
        }
    }

    private var lookingUpView: some View {
        VStack(spacing: PaktSpace.s4) {
            Spacer()
            ProgressView().tint(Color.paktPrimary)
            Text("Looking up your invite…")
                .font(.pakt(.body))
                .foregroundStyle(Color.paktMutedForeground)
            Spacer()
        }
    }

    private var confirmView: some View {
        VStack(spacing: PaktSpace.s4) {
            Spacer()

            VStack(spacing: PaktSpace.s2) {
                Text("Join this move?")
                    .font(.pakt(.heading))
                    .foregroundStyle(Color.paktMutedForeground)
                Text(resolvedInvite?.moveName ?? "")
                    .font(.pakt(.title))
                    .foregroundStyle(Color.paktForeground)
                    .multilineTextAlignment(.center)
                Text("Shared by \(resolvedInvite?.inviterName ?? "someone")")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }

            Spacer()

            PaktButton("Join", size: .lg) {
                if case .signedIn = auth.state {
                    Task { await performAccept() }
                } else {
                    showingSignInPromo = true
                }
            }
            PaktButton("Cancel", variant: .ghost, size: .lg) {
                dismiss()
            }
            .padding(.bottom, PaktSpace.s6)
        }
    }

    private var acceptingView: some View {
        VStack(spacing: PaktSpace.s4) {
            Spacer()
            ProgressView().tint(Color.paktPrimary)
            Text("Joining and syncing the move…")
                .font(.pakt(.body))
                .foregroundStyle(Color.paktMutedForeground)
            Spacer()
        }
    }

    private var acceptedView: some View {
        VStack(spacing: PaktSpace.s3) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.paktPrimary)
            Text("You're in!")
                .font(.pakt(.title))
                .foregroundStyle(Color.paktForeground)
            Text("The move is now in your Moves list.")
                .font(.pakt(.body))
                .foregroundStyle(Color.paktMutedForeground)
                .multilineTextAlignment(.center)
            Spacer()
            PaktButton("Done", size: .lg) { dismiss() }
                .padding(.bottom, PaktSpace.s6)
        }
    }

    private var failedView: some View {
        VStack(spacing: PaktSpace.s3) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.paktDestructive)
            Text("Couldn't join")
                .font(.pakt(.heading))
                .foregroundStyle(Color.paktForeground)
            if let msg = errorMessage {
                Text(msg)
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaktSpace.s4)
            }
            PaktButton("Try again", size: .lg) {
                phase = .enterCode
                errorMessage = nil
            }
            .padding(.top, PaktSpace.s2)
            Spacer()
        }
    }

    // MARK: - Actions

    private var normalizedCodeBody: String {
        rawCode
            .uppercased()
            .replacingOccurrences(of: "PAKT-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func lookup() async {
        phase = .lookingUp
        do {
            let invite = try await inviteCodeHolder.service.resolve(code: rawCode)
            resolvedInvite = invite
            phase = .confirm
        } catch let err as LocalizedError {
            errorMessage = err.errorDescription
            phase = .failed
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    private func performAccept() async {
        guard case .signedIn = auth.state else {
            showingSignInPromo = true
            return
        }
        guard let invite = resolvedInvite else { return }
        phase = .accepting
        do {
            try await syncEngine.acceptInvite(url: invite.shareURL)
            try? await inviteCodeHolder.service.consume(code: invite.code)
            phase = .accepted
        } catch let err as LocalizedError {
            errorMessage = err.errorDescription
            phase = .failed
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }
}
