import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage(OnboardingKey.completed) private var onboardingCompleted = false

    var body: some View {
        Group {
            if !onboardingCompleted {
                OnboardingView()
            } else {
                switch auth.state {
                case .loading:
                    ZStack {
                        Color.paktBackground.ignoresSafeArea()
                        ProgressView().tint(Color.paktPrimary)
                    }
                case .guest, .reconciling, .signedIn:
                    MovesListView()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { auth.mergeDecisionRequired },
            set: { _ in }
        )) {
            MergeDecisionSheet()
                .environment(auth)
        }
        .animation(.easeInOut(duration: 0.25), value: onboardingCompleted)
    }
}
