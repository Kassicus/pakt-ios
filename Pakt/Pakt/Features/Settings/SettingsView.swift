import SwiftData
import SwiftUI
import TipKit

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(CloudKitSyncEngine.self) private var syncEngine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var users: [User]

    @AppStorage(AppearanceKey.preference) private var appearanceRaw = AppearancePreference.dark.rawValue
    @AppStorage(OnboardingKey.completed) private var onboardingCompleted = false

    @State private var confirmSignOut = false
    @State private var showingSignInPromo = false
    @State private var isResyncing = false
    @State private var confirmResync = false
    @State private var resyncResult: ResyncResult?

    private enum ResyncResult: Identifiable {
        case success
        case failure(String)

        var id: String {
            switch self {
            case .success: return "ok"
            case .failure(let m): return "err:\(m)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            PaktScreen(accent: .paktPrimary) {
                heroHeader
                accountSurface
                appearanceSurface
                dataSurface
                aboutSurface
                if isSignedIn {
                    signOutButton
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
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
                Text("Your moves stay on this device. Sign back in anytime to resume iCloud sync and invite collaborators.")
            }
            .sheet(isPresented: $showingSignInPromo) {
                SignInPromoView(context: .settings)
                    .environment(auth)
            }
            .confirmationDialog(
                "Force re-sync shared moves?",
                isPresented: $confirmResync,
                titleVisibility: .visible
            ) {
                Button("Re-sync now") { runForceResync() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Rebuilds every shared move's data on iCloud. Collaborators may see data briefly disappear and reappear. Your local data is untouched.")
            }
            .alert(item: $resyncResult) { result in
                switch result {
                case .success:
                    return Alert(
                        title: Text("Re-sync complete"),
                        message: Text("Ask collaborators to open the app to pull the latest data."),
                        dismissButton: .default(Text("OK"))
                    )
                case .failure(let message):
                    return Alert(
                        title: Text("Re-sync failed"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private func runForceResync() {
        guard !isResyncing else { return }
        isResyncing = true
        Task {
            do {
                try await syncEngine.forceResyncSharedMoves()
                await MainActor.run {
                    isResyncing = false
                    resyncResult = .success
                }
            } catch {
                await MainActor.run {
                    isResyncing = false
                    resyncResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        PaktHeroHeader(
            eyebrow: "Account",
            title: "Settings",
            subtitle: isSignedIn ? (currentUser?.displayName ?? "Signed in with Apple") : "Guest",
            accent: .paktPrimary,
            titleStyle: .hero
        ) {
            if isSignedIn {
                ZStack {
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.paktPrimary.opacity(0.28), Color.paktAccent.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Circle().strokeBorder(Color.paktPrimary.opacity(0.4), lineWidth: 1)
                    Text(initials)
                        .font(.pakt(.title))
                        .foregroundStyle(Color.paktPrimary)
                }
                .frame(width: 64, height: 64)
            }
        }
    }

    // MARK: - Surfaces

    @ViewBuilder private var accountSurface: some View {
        if isSignedIn {
            PaktSurface(title: "Account", icon: "user", accent: .paktPrimary) {
                PaktFieldStack {
                    PaktField("Signed in as") {
                        Text(currentUser?.displayName ?? "Apple ID")
                            .foregroundStyle(Color.paktForeground)
                    }
                    if let email = currentUser?.email {
                        PaktField("Email") {
                            Text(email)
                        }
                    }
                }
            }
        } else {
            Button { showingSignInPromo = true } label: {
                PaktSurface(accent: .paktMutedForeground, padding: PaktSpace.s4) {
                    HStack(spacing: PaktSpace.s3) {
                        ZStack {
                            Circle().fill(Color.paktMutedForeground.opacity(0.12))
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not signed in")
                                .font(.pakt(.bodyMedium))
                                .foregroundStyle(Color.paktForeground)
                            Text("Sign in with Apple to back up to iCloud and invite collaborators.")
                                .font(.pakt(.small))
                                .foregroundStyle(Color.paktMutedForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var appearanceSurface: some View {
        PaktSurface(title: "Appearance", icon: "sliders", accent: .paktAccent) {
            HStack(spacing: 8) {
                ForEach(AppearancePreference.allCases) { pref in
                    let isSelected = appearanceRaw == pref.rawValue
                    Button {
                        appearanceRaw = pref.rawValue
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: iconFor(pref))
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Color.paktPrimaryForeground : Color.paktForeground)
                            Text(pref.label)
                                .font(.pakt(.small))
                                .foregroundStyle(isSelected ? Color.paktPrimaryForeground : Color.paktForeground)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PaktSpace.s3)
                        .background(
                            RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                                .fill(isSelected ? Color.paktPrimary : Color.paktMuted)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dataSurface: some View {
        PaktSurface(title: "Data", icon: "activity", accent: .paktStorage) {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                HStack(spacing: PaktSpace.s3) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isSignedIn ? Color.paktPrimary : Color.paktMutedForeground)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill((isSignedIn ? Color.paktPrimary : Color.paktMutedForeground).opacity(0.14))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud sync")
                            .font(.pakt(.bodyMedium))
                            .foregroundStyle(Color.paktForeground)
                        Text(isSignedIn
                             ? "Changes sync automatically across your devices."
                             : "Sign in with Apple to sync your moves across devices.")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(isSignedIn ? "ON" : "OFF")
                        .font(.pakt(.small))
                        .tracking(1.0)
                        .foregroundStyle(isSignedIn ? Color.paktPrimary : Color.paktMutedForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill((isSignedIn ? Color.paktPrimary : Color.paktMutedForeground).opacity(0.14))
                        )
                }

                if isSignedIn {
                    Rectangle().fill(Color.paktBorder.opacity(0.6)).frame(height: 1)
                    Button { confirmResync = true } label: {
                        HStack(spacing: PaktSpace.s3) {
                            ZStack {
                                Circle().fill(Color.paktStorage.opacity(0.14))
                                if isResyncing {
                                    ProgressView()
                                        .tint(Color.paktStorage)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color.paktStorage)
                                }
                            }
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Force re-sync shared moves")
                                    .font(.pakt(.bodyMedium))
                                    .foregroundStyle(Color.paktForeground)
                                Text("Rebuilds the shared data on iCloud so invited collaborators can see every room, item, and box.")
                                    .font(.pakt(.small))
                                    .foregroundStyle(Color.paktMutedForeground)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(paktIcon: "chevron-right")
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isResyncing)
                    .opacity(isResyncing ? 0.6 : 1)
                }
            }
        }
    }

    private var aboutSurface: some View {
        PaktSurface(title: "About", icon: "info") {
            VStack(alignment: .leading, spacing: PaktSpace.s2) {
                PaktFieldStack {
                    PaktField("Version") {
                        Text(versionString)
                            .font(.pakt(.body).monospacedDigit())
                    }
                }
                Rectangle().fill(Color.paktBorder.opacity(0.6)).frame(height: 1)
                Button {
                    withAnimation { onboardingCompleted = false }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.paktPrimary)
                        Text("Replay intro")
                            .foregroundStyle(Color.paktForeground)
                        Spacer()
                        Image(paktIcon: "chevron-right")
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                    .font(.pakt(.body))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                Button {
                    try? Tips.resetDatastore()
                } label: {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(Color.paktDonate)
                        Text("Reset tips")
                            .foregroundStyle(Color.paktForeground)
                        Spacer()
                        Image(paktIcon: "chevron-right")
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                    .font(.pakt(.body))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signOutButton: some View {
        PaktButton(variant: .destructive, action: { confirmSignOut = true }) {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign out")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, PaktSpace.s2)
    }

    // MARK: - Derived

    private func iconFor(_ pref: AppearancePreference) -> String {
        switch pref {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = auth.state { return true }
        return false
    }

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
