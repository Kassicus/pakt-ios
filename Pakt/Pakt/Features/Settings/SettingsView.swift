import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var users: [User]

    @AppStorage(AppearanceKey.preference) private var appearanceRaw = AppearancePreference.dark.rawValue
    @AppStorage(OnboardingKey.completed) private var onboardingCompleted = false

    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                appearanceSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.paktBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.paktMutedForeground)
                }
            }
            .confirmationDialog(
                "Sign out of Pakt?",
                isPresented: $confirmSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data stays on this device and in iCloud. Sign back in with the same Apple ID anytime.")
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            HStack(spacing: PaktSpace.s3) {
                ZStack {
                    Circle().fill(Color.paktPrimary.opacity(0.15))
                    Text(initials)
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktPrimary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentUser?.displayName ?? "Signed in with Apple")
                        .font(.pakt(.bodyMedium))
                        .foregroundStyle(Color.paktForeground)
                    if let email = currentUser?.email {
                        Text(email)
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    } else {
                        Text("Apple ID")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceRaw) {
                ForEach(AppearancePreference.allCases) { pref in
                    Text(pref.label).tag(pref.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud sync").font(.pakt(.body))
                    Text("Changes sync automatically across your devices signed in with the same Apple ID.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                }
            } icon: {
                Image(systemName: "icloud.fill")
                    .foregroundStyle(Color.paktPrimary)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(versionString)
                    .font(.pakt(.body).monospacedDigit())
                    .foregroundStyle(Color.paktMutedForeground)
            }
            Button {
                withAnimation { onboardingCompleted = false }
                dismiss()
            } label: {
                Label("Replay intro", systemImage: "sparkles")
            }
            Button(role: .destructive) { confirmSignOut = true } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    // MARK: - Derived

    private var currentUser: User? {
        guard case .signedIn(let appleUserId, _) = auth.state else { return nil }
        return users.first { $0.appleUserId == appleUserId }
    }

    private var initials: String {
        guard let name = currentUser?.displayName, !name.isEmpty else { return "P" }
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
