import Foundation
import SwiftData

/// Purges soft-deleted rows whose `deletedAt` is older than
/// `TrashSweeper.retention`. Call once on app launch — gated behind
/// `TrashSweeper.isEnabled` so we can roll it out cautiously.
///
/// Soft-deleted rows are hidden from the UI the moment the user taps delete,
/// but remain in the store for a grace window so sync can propagate the
/// tombstone and the user can still restore via the undo toast.
enum TrashSweeper {
    /// Master switch while the new tombstone sync is being validated. Flip to
    /// true once CloudKit tombstone propagation has been verified in the wild.
    static let isEnabled: Bool = false

    /// How long a tombstoned row lives before it's eligible for hard-delete.
    static let retention: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    @MainActor
    static func sweep(context: ModelContext, now: Date = Date()) {
        guard isEnabled else { return }
        let cutoff = now.addingTimeInterval(-retention)

        purge(Box.self, cutoff: cutoff, context: context)
        purge(BoxType.self, cutoff: cutoff, context: context)
        purge(Item.self, cutoff: cutoff, context: context)
        purge(ItemPhoto.self, cutoff: cutoff, context: context)
        purge(Room.self, cutoff: cutoff, context: context)
        purge(Move.self, cutoff: cutoff, context: context)

        try? context.save()
    }

    @MainActor
    private static func purge<T: PersistentModel>(
        _ type: T.Type,
        cutoff: Date,
        context: ModelContext
    ) {
        guard let results = try? context.fetch(FetchDescriptor<T>()) else { return }
        for model in results {
            guard let deletedAt = Mirror(reflecting: model)
                .children.first(where: { $0.label == "deletedAt" })?.value as? Date
            else { continue }
            if deletedAt <= cutoff {
                context.delete(model)
            }
        }
    }
}
