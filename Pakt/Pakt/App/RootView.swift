import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        switch auth.state {
        case .loading:
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                ProgressView().tint(Color.paktPrimary)
            }
        case .signedOut:
            SignInView()
        case .signedIn:
            MovesListView()
        }
    }
}
