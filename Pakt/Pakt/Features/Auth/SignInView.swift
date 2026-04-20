import AuthenticationServices
import SwiftData
import SwiftUI

/// Full-screen onboarding-era Sign In view. After the "optional sign-in"
/// refactor this is only shown as the last step of onboarding — it offers
/// both "Sign in with Apple" and "Start without signing in" paths.
///
/// Other invocations (settings, invite gates) use `SignInPromoView` as a
/// sheet instead.
struct SignInView: View {
    /// Called when the user taps "Start without signing in". Guest mode.
    var onSkip: (() -> Void)? = nil
    /// Called when Sign in with Apple completes successfully. Hosts use this
    /// to dismiss the cover/sheet and advance the onboarding flow.
    var onSignedIn: (() -> Void)? = nil

    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(spacing: PaktSpace.s6) {
                Spacer()
                VStack(spacing: PaktSpace.s3) {
                    Text("pakt")
                        .font(.pakt(.hero))
                        .foregroundStyle(Color.paktForeground)
                    Text("Move without the mess.")
                        .font(.pakt(.heading))
                        .foregroundStyle(Color.paktMutedForeground)
                }

                Spacer()

                VStack(spacing: PaktSpace.s3) {
                    SignInWithAppleButton(.signIn, onRequest: configure, onCompletion: handleCompletion)
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .cornerRadius(PaktRadius.lg)

                    if onSkip != nil {
                        Button {
                            onSkip?()
                        } label: {
                            Text("Start without signing in")
                                .font(.pakt(.body))
                                .foregroundStyle(Color.paktMutedForeground)
                                .padding(.vertical, PaktSpace.s2)
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("signin.skip")
                    }
                }

                if let err = auth.lastError {
                    Text(err)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktDestructive)
                        .multilineTextAlignment(.center)
                }

                Text(onSkip != nil
                     ? "Sign in to sync to iCloud and invite collaborators. You can always sign in later from Settings."
                     : "Your data stays on your devices and syncs via iCloud.")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PaktSpace.s5)
            .padding(.bottom, PaktSpace.s8)
        }
        .onChange(of: auth.state) { _, newValue in
            switch newValue {
            case .signedIn, .reconciling:
                onSignedIn?()
            default:
                break
            }
        }
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            auth.handleAuthorization(authorization, context: context)
        case .failure(let error):
            auth.handleAuthorizationError(error)
        }
    }
}
