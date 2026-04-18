import Foundation
import SwiftData

enum AppModelContainer {
    /// Build a production-ready container with CloudKit sync in the private DB.
    /// CloudKit entitlement + iCloud container must be enabled on the Pakt target.
    @MainActor
    static func make() -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to local-only storage if CloudKit container isn't set up yet
            // (e.g. running in simulator before iCloud capability is configured).
            let localOnly = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localOnly])
            } catch {
                fatalError("Failed to build ModelContainer: \(error)")
            }
        }
    }

    @MainActor
    static func inMemory() -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
