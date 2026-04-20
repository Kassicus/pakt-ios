import CloudKit
import UIKit
import UserNotifications

/// Minimal `UIApplicationDelegate` wired in via `@UIApplicationDelegateAdaptor`.
///
/// Its only job is to route silent CloudKit pushes (which don't run through
/// SwiftUI's `onContinueUserActivity` / `onOpenURL`) into the `CloudKitSyncEngine`
/// so we can pull fresh zone changes.
///
/// Registration for remote notifications happens in `didFinishLaunching`.
/// `onRemoteNotification` is set by `PaktApp` once the sync engine is alive.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by `PaktApp` at launch. Called from the main actor with the raw
    /// `userInfo` payload for any silent CloudKit push so the sync engine
    /// can parse it and fetch changes.
    public static var onRemoteNotification: (@MainActor ([AnyHashable: Any]) async -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // CKSubscription silent pushes don't require user permission — the
        // push payload carries content-available=1. We just need to register
        // for remote notifications so APNs will deliver to us.
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Only respond to CloudKit-originated pushes. `ck` key is the signal.
        guard userInfo["ck"] != nil else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            if let handler = Self.onRemoteNotification {
                await handler(userInfo)
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
        }
    }
}
