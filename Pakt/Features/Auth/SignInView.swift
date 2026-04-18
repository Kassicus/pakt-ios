import SwiftUI

struct SignInView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: PaktSpace.s5) {
                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: PaktSpace.s2) {
                    Text("pakt").font(.pakt(.title))
                        .foregroundStyle(Color.paktForeground)
                    Text("Move without the mess.")
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktMutedForeground)
                }

                VStack(alignment: .leading, spacing: PaktSpace.s3) {
                    Text("Email").font(.pakt(.small)).foregroundStyle(Color.paktMutedForeground)
                    PaktTextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    Text("Password").font(.pakt(.small)).foregroundStyle(Color.paktMutedForeground)
                    PaktTextField("Password", text: $password, isSecure: true)
                        .textContentType(.password)
                }

                if let err = auth.lastError {
                    Text(err).font(.pakt(.small)).foregroundStyle(Color.paktDestructive)
                }

                PaktButton(size: .lg, action: submit) {
                    HStack {
                        if auth.isBusy { ProgressView().tint(.paktPrimaryForeground) }
                        Text("Sign in").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit || auth.isBusy)
                .opacity(canSubmit ? 1 : 0.6)

                Button("Create an account") { showSignUp = true }
                    .font(.pakt(.body))
                    .foregroundStyle(Color.paktPrimary)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.horizontal, PaktSpace.s4)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView().environment(auth)
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func submit() {
        Task { await auth.signIn(email: email, password: password) }
    }
}
