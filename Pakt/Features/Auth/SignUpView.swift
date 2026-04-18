import SwiftUI

struct SignUpView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var verificationCode = ""
    @State private var awaitingCode = false

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: PaktSpace.s4) {
                    Text(awaitingCode ? "Check your email" : "Create your account")
                        .font(.pakt(.title))
                        .foregroundStyle(Color.paktForeground)

                    if awaitingCode {
                        Text("We sent a 6-digit code to \(email).")
                            .font(.pakt(.body))
                            .foregroundStyle(Color.paktMutedForeground)
                        PaktTextField("Verification code", text: $verificationCode)
                            .keyboardType(.numberPad)
                        PaktButton("Verify", size: .lg, action: verify)
                            .disabled(verificationCode.isEmpty || auth.isBusy)
                    } else {
                        PaktTextField("First name", text: $firstName).textContentType(.givenName)
                        PaktTextField("Last name",  text: $lastName).textContentType(.familyName)
                        PaktTextField("Email",      text: $email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        PaktTextField("Password",   text: $password, isSecure: true)
                            .textContentType(.newPassword)

                        if let err = auth.lastError {
                            Text(err).font(.pakt(.small)).foregroundStyle(Color.paktDestructive)
                        }

                        PaktButton("Create account", size: .lg, action: submit)
                            .disabled(!canSubmit || auth.isBusy)
                            .opacity(canSubmit ? 1 : 0.6)
                    }

                    Button("Cancel") { dismiss() }
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktMutedForeground)
                        .frame(maxWidth: .infinity)
                }
                .padding(PaktSpace.s4)
            }
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 8
    }

    private func submit() {
        Task {
            await auth.signUp(email: email, password: password,
                              firstName: firstName.isEmpty ? nil : firstName,
                              lastName: lastName.isEmpty ? nil : lastName)
            if auth.lastError == nil { awaitingCode = true }
        }
    }

    private func verify() {
        Task { await auth.verifyEmailCode(verificationCode) }
    }
}
