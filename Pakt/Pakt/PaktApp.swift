//
//  PaktApp.swift
//  Pakt
//

import CloudKit
import SwiftData
import SwiftUI
import TipKit

@main
struct PaktApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var auth = AuthStore()
    @State private var collab: CloudKitCollab
    @State private var inviteCodeHolder = InviteCodeServiceHolder()
    @State private var syncEngine: CloudKitSyncEngine
    @AppStorage(AppearanceKey.preference) private var appearanceRaw = AppearancePreference.dark.rawValue
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer

    init() {
        Fonts.registerIfNeeded()
        self.container = AppModelContainer.make()
        let collabInstance = CloudKitCollab()
        self._collab = State(initialValue: collabInstance)
        self._syncEngine = State(initialValue: CloudKitSyncEngine(collab: collabInstance))

        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault),
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(collab)
                .environment(inviteCodeHolder)
                .environment(syncEngine)
                .undoToastHost()
                .preferredColorScheme(appearancePreference.colorScheme)
                .task {
                    await auth.bootstrap()
                    TrashSweeper.sweep(context: container.mainContext)
                    // Start observing SwiftData saves + install subscriptions
                    // + initial pull.
                    syncEngine.start(modelContainer: container)
                    // Route remote pushes into the engine.
                    AppDelegate.onRemoteNotification = { [weak syncEngine] userInfo in
                        await syncEngine?.handleRemotePush(userInfo: userInfo)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await syncEngine.pullAll() }
                    }
                }
                .onContinueUserActivity("com.apple.CloudKit.ShareMetadataActivityType") { activity in
                    Task {
                        // Accept via the sync engine so the materialize save
                        // doesn't trigger a spurious push back to CloudKit.
                        await syncEngine.acceptInvite(activity: activity)
                        await syncEngine.setupSubscriptions()
                        await syncEngine.pullAll()
                    }
                }
        }
        .modelContainer(container)
    }

    private var appearancePreference: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .dark
    }
}
