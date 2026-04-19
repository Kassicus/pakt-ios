//
//  PaktApp.swift
//  Pakt
//

import SwiftData
import SwiftUI

@main
struct PaktApp: App {
    @State private var auth = AuthStore()
    @AppStorage(AppearanceKey.preference) private var appearanceRaw = AppearancePreference.dark.rawValue
    let container: ModelContainer

    init() {
        Fonts.registerIfNeeded()
        self.container = AppModelContainer.make()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .preferredColorScheme(appearancePreference.colorScheme)
                .task { await auth.bootstrap() }
        }
        .modelContainer(container)
    }

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .dark
    }
}
