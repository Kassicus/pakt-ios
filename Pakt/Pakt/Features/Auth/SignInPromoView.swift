import AuthenticationServices
import SwiftData
import SwiftUI

/// Context-aware sign-in sheet. Used anywhere sign-in is optional but
/// recommended, or required for a specific action (inviting collaborators,
/// joining a shared move).
struct SignInPromoView: View {
    enum Context {
        case settings
        case invite
        case accept

        var title: String {
            switch self {
            case .settings: return "Sign in with Apple"
            case .invite:   return "Sign in to invite"
            case .accept:   return "Sign in to join"
            }
        }

        var body: String {
            switch self {
            case .settings:
                return "Sign in to back up your moves to iCloud and invite collaborators. Your data still stays private."
            case .invite:
                return "Inviting a collaborator needs an Apple ID so your co-planner knows who shared the move with them."
            case .accept:
                return "Joining a shared move needs your Apple ID so the owner can see you in the collaborators list."
            }
        }
    }

    let context: Context
    var onComplete: (() -> Void)? = nil

    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(spacing: PaktSpace.s5) {
                Spacer()

                VStack(spacing: PaktSpace.s3) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(Color.paktPrimary)

                    Text(context.title)
                        .font(.pakt(.title))
                        .foregroundStyle(Color.paktForeground)
                        .multilineTextAlignment(.center)

                    Text(context.body)
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktMutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PaktSpace.s4)
                }

                Spacer()

                SignInWithAppleButton(.signIn, onRequest: configure, onCompletion: handleCompletion)
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(PaktRadius.lg)

                if let err = auth.lastError {
                    Text(err)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktDestructive)
                        .multilineTextAlignment(.center)
                }

                Button("Not now") { dismiss() }
                    .font(.pakt(.body))
                    .foregroundStyle(Color.paktMutedForeground)
                    .padding(.top, PaktSpace.s1)
            }
            .padding(.horizontal, PaktSpace.s5)
            .padding(.bottom, PaktSpace.s6)
        }
        .onChange(of: auth.state) { _, newValue in
            if case .signedIn = newValue {
                onComplete?()
                dismiss()
            }
        }
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            auth.handleAuthorization(authorization, context: modelContext)
        case .failure(let error):
            auth.handleAuthorizationError(error)
        }
    }
}
