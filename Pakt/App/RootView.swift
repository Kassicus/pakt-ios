import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(MovesStore.self) private var moves

    var body: some View {
        switch auth.state {
        case .loading:
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                ProgressView()
            }
        case .signedOut:
            SignInView()
        case .signedIn:
            MovesListView()
        }
    }
}
