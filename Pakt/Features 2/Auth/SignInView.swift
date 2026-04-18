import AuthenticationServices
import SwiftData
import SwiftUI

struct SignInView: View {
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

                Text("Your data stays on your devices and syncs via iCloud.")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PaktSpace.s5)
            .padding(.bottom, PaktSpace.s8)
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
