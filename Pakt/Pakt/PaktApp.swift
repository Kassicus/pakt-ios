//
//  PaktApp.swift
//  Pakt
//

import SwiftData
import SwiftUI

@main
struct PaktApp: App {
    @State private var auth = AuthStore()
    let container: ModelContainer

    init() {
        Fonts.registerIfNeeded()
        self.container = AppModelContainer.make()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .preferredColorScheme(.dark)
                .task { await auth.bootstrap() }
        }
        .modelContainer(container)
    }
}
