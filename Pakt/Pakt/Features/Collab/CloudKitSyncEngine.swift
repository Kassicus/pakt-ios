import CloudKit
import CoreData
import Foundation
import SwiftData
import SwiftUI

/// Orchestrates bidirectional real-time sync for shared Moves.
///
/// Responsibilities:
/// - Observes SwiftData saves (via the underlying NSManagedObjectContextDidSave
///   notification) and pushes changed records to CloudKit.
/// - Pulls remote changes via silent CKSubscription pushes, scene-foreground
///   triggers, and explicit `pullMove(_:)` calls.
/// - Persists per-zone CKServerChangeTokens so pulls are incremental.
/// - Installs/removes subscriptions as shares are created and stopped.
///
/// This is a `@MainActor` class because all SwiftData work must happen on the
/// main actor. CloudKit I/O is awaited directly; it doesn't need its own actor.
@Observable
@MainActor
public final class CloudKitSyncEngine {
    public enum State: Equatable {
        case idle
        case syncing
        case error(String)
    }

    public private(set) var state: State = .idle

    private let collab: CloudKitCollab
    private weak var modelContainer: ModelContainer?
    private var context: ModelContext? { modelContainer?.mainContext }

    private var saveObserver: NSObjectProtocol?
    private var dirtyMoveIDs: Set<String> = []
    private var dirtyDeletedRecordIDs: [String: [CKRecord.ID]] = [:]  // keyed by moveID
    private var pushDebounce: Task<Void, Never>?
    private var started = false

    /// Set to true while we're writing CloudKit-sourced changes into the
    /// local SwiftData store. When this is true we ignore didSave
    /// notifications so we don't immediately push those same changes back to
    /// CloudKit — which would create a never-ending pull→save→push→pull loop
    /// (and was the cause of the app instability after real-time sync
    /// shipped).
    private var isApplyingRemote = false

    public init(collab: CloudKitCollab) {
        self.collab = collab
    }

    // MARK: - Lifecycle

    /// Start observing saves and scheduling pulls. Called once from `PaktApp`
    /// after `auth.bootstrap()`. Safe to call multiple times.
    public func start(modelContainer: ModelContainer) {
        guard !started else { return }
        started = true
        self.modelContainer = modelContainer

        // NSManagedObjectContextDidSave fires for every SwiftData save because
        // SwiftData wraps NSManagedObjectContext under the hood. This is our
        // hook for "something changed in the app; maybe we need to push."
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil  // deliver on the posting thread; we hop to MainActor
        ) { [weak self] note in
            // `MainActor.assumeIsolated` crashes if the caller isn't already
            // MainActor-isolated, which NotificationCenter doesn't guarantee
            // under Swift 6 strict concurrency — even with queue: .main.
            // Hopping via a Task is safe in both directions.
            Task { @MainActor [weak self] in
                self?.contextDidSave(note)
            }
        }

        // Kick an initial pull + subscription refresh.
        Task { [weak self] in
            await self?.setupSubscriptions()
            await self?.pullAll()
        }
    }

    public func stop() {
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
            self.saveObserver = nil
        }
        pushDebounce?.cancel()
        pushDebounce = nil
        started = false
    }

    // MARK: - Push (local → CloudKit)

    private func contextDidSave(_ note: Notification) {
        // Ignore saves that happened because we were applying remote changes
        // — otherwise we'd immediately push those same changes back and spin
        // forever.
        guard !isApplyingRemote else { return }
        guard let userInfo = note.userInfo else { return }

        let inserted = (userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updated = (userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
        let deleted = (userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>) ?? []

        var touchedAny = false
        for obj in inserted.union(updated) {
            if let moveID = owningMoveID(for: obj), isShared(moveID: moveID) {
                dirtyMoveIDs.insert(moveID)
                touchedAny = true
            }
        }
        for obj in deleted {
            if let moveID = owningMoveID(for: obj), isShared(moveID: moveID) {
                // Synthesize the CKRecord.ID for the deleted entity.
                if let recordName = idValue(of: obj) {
                    let zoneID = MoveCKRecordMapper.zoneID(for: moveID)
                    let id = CKRecord.ID(recordName: recordName, zoneID: zoneID)
                    dirtyDeletedRecordIDs[moveID, default: []].append(id)
                    touchedAny = true
                }
            }
        }

        guard touchedAny else { return }
        schedulePush()
    }

    private func schedulePush() {
        pushDebounce?.cancel()
        pushDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            await self.flushDirty()
        }
    }

    private func flushDirty() async {
        guard let context else { return }
        let moveIDsToPush = dirtyMoveIDs
        let deletionsToPush = dirtyDeletedRecordIDs
        dirtyMoveIDs.removeAll()
        dirtyDeletedRecordIDs.removeAll()

        guard !moveIDsToPush.isEmpty || !deletionsToPush.isEmpty else { return }
        state = .syncing
        defer { state = .idle }

        for moveID in moveIDsToPush {
            guard let move = fetchMove(id: moveID, context: context), move.isShared else { continue }
            let role = await collab.currentRole(for: move)
            let db = collab.database(for: role)

            // Build records for the full Move cascade and push as an upsert.
            // This is heavy-handed vs. a true per-object diff, but it's
            // simple, correct, and keeps the server authoritative for the
            // entire shared move. The 500ms debounce coalesces rapid edits.
            let records = MoveCKRecordMapper.records(for: move)
            do {
                try await collab.pushRecords(records, to: db)
            } catch {
                state = .error(error.localizedDescription)
            }
        }

        for (moveID, recordIDs) in deletionsToPush {
            // For deletions we only need a database; since the Move may be
            // gone locally, infer the role by trying owner first.
            let db: CKDatabase
            if let move = fetchMove(id: moveID, context: context) {
                let role = await collab.currentRole(for: move)
                db = collab.database(for: role)
            } else {
                // Move itself was deleted. Assume owner's private DB; if we
                // weren't the owner, the delete will no-op on the participant
                // side and that's fine.
                db = collab.database(for: .owner)
            }
            try? await collab.deleteRecords(recordIDs, from: db)
        }
    }

    // MARK: - Pull (CloudKit → local)

    /// Pull remote changes for every shared Move on this device. Called on
    /// app foreground, engine start, and via explicit UI refresh.
    public func pullAll() async {
        guard let context else { return }
        state = .syncing
        defer { state = .idle }

        // Participant side: discover any newly-accessible zones in the
        // shared DB (e.g. a new share was just accepted).
        await pullSharedDatabaseChanges()

        // For each local shared Move, pull its zone.
        let moves = (try? context.fetch(FetchDescriptor<Move>(
            predicate: #Predicate { $0.isShared == true }
        ))) ?? []

        for move in moves {
            await pullMove(move)
        }
    }

    /// Pull the latest state for a specific shared Move.
    public func pullMove(_ move: Move) async {
        guard let context else { return }
        guard move.isShared else { return }

        let role = await collab.currentRole(for: move)
        let db = collab.database(for: role)
        let zoneID = MoveCKRecordMapper.zoneID(for: move.id)

        var token = CloudKitChangeTokens.zoneToken(for: zoneID.zoneName)

        do {
            while true {
                let delta = try await collab.fetchZoneDelta(
                    zoneID: zoneID,
                    database: db,
                    token: token
                )

                isApplyingRemote = true
                if !delta.records.isEmpty {
                    MoveCKRecordMapper.materialize(
                        records: delta.records,
                        shareURL: URL(string: move.cloudKitShareURLString ?? ""),
                        ownerAppleUserId: move.ownerAppleUserId,
                        zoneName: zoneID.zoneName,
                        context: context
                    )
                }
                if !delta.deletedIDs.isEmpty {
                    MoveCKRecordMapper.applyDeletions(
                        recordIDs: delta.deletedIDs,
                        context: context
                    )
                }
                isApplyingRemote = false

                token = delta.newToken
                if !delta.moreComing { break }
            }
            CloudKitChangeTokens.setZoneToken(token, for: zoneID.zoneName)
        } catch let err as CKError where err.code == .changeTokenExpired {
            // Token is stale; reset and refetch from scratch.
            CloudKitChangeTokens.setZoneToken(nil, for: zoneID.zoneName)
            await pullMove(move)
        } catch let err as CKError where err.code == .zoneNotFound || err.code == .userDeletedZone {
            // Share was stopped or zone destroyed; mark local as unshared.
            isApplyingRemote = true
            move.isShared = false
            try? context.save()
            isApplyingRemote = false
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Participant-side DB-scope pull: discover new/changed zones from the
    /// shared DB, then pull each one. Also handles zone deletions (owner
    /// stopped sharing — we clear local CKShare metadata).
    private func pullSharedDatabaseChanges() async {
        guard let context else { return }
        let db = collab.database(for: .participant)

        var token = CloudKitChangeTokens.databaseToken(scope: .shared)
        do {
            let result = try await collab.fetchDatabaseChanges(database: db, token: token)

            for zoneID in result.changedZoneIDs {
                // Find or create the Move and pull its zone.
                let moveID = zoneID.zoneName.hasPrefix("move-")
                    ? String(zoneID.zoneName.dropFirst("move-".count))
                    : zoneID.zoneName
                if let move = fetchMove(id: moveID, context: context) {
                    await pullMove(move)
                }
                // If we can't find the Move locally yet, `acceptShare` should
                // have created it during the accept flow; a later `pullAll`
                // will catch up.
            }

            isApplyingRemote = true
            for zoneID in result.deletedZoneIDs {
                let moveID = zoneID.zoneName.hasPrefix("move-")
                    ? String(zoneID.zoneName.dropFirst("move-".count))
                    : zoneID.zoneName
                if let move = fetchMove(id: moveID, context: context) {
                    context.delete(move)
                }
            }
            if !result.changedZoneIDs.isEmpty || !result.deletedZoneIDs.isEmpty {
                try? context.save()
            }
            isApplyingRemote = false
            CloudKitChangeTokens.setDatabaseToken(result.newToken, scope: .shared)
        } catch let err as CKError where err.code == .changeTokenExpired {
            CloudKitChangeTokens.setDatabaseToken(nil, scope: .shared)
        } catch {
            // Transient errors are fine — we'll retry on next trigger.
        }
    }

    // MARK: - Subscriptions

    /// Install subscriptions for every current shared Move + the shared DB.
    /// Idempotent; safe to call repeatedly.
    public func setupSubscriptions() async {
        guard let context else { return }

        // Participant-side: one DB subscription covers every shared zone.
        try? await collab.installSharedDBSubscription()

        // Owner-side: per-zone subscription so we get pushes when participants
        // edit our shared moves.
        let moves = (try? context.fetch(FetchDescriptor<Move>(
            predicate: #Predicate { $0.isShared == true }
        ))) ?? []
        for move in moves {
            let role = await collab.currentRole(for: move)
            if role == .owner {
                let zoneID = MoveCKRecordMapper.zoneID(for: move.id)
                try? await collab.installZoneSubscription(zoneID: zoneID)
            }
        }
    }

    // MARK: - Accept invite (flag-guarded wrapper)

    /// Accept a CKShare URL and materialize the shared move into local
    /// SwiftData. Wraps `CloudKitCollab.acceptShare` so the resulting
    /// `context.save()` doesn't trigger an immediate re-push of the same
    /// records.
    public func acceptInvite(url: URL) async throws {
        guard let context else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        try await collab.acceptShare(at: url, context: context)
    }

    /// Accept via NSUserActivity continuation. Same flag-guarded path.
    public func acceptInvite(activity: NSUserActivity) async {
        guard let context else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        await collab.accept(activity: activity, context: context)
    }

    // MARK: - Push notification entry point

    /// Called by AppDelegate for every silent CloudKit push. We don't parse
    /// the CKNotification payload in detail — just pull everything. The
    /// payload is noisy enough that specialized routing offers little.
    public func handleRemotePush(userInfo: [AnyHashable: Any]) async {
        await pullAll()
    }

    // MARK: - Helpers

    private func isShared(moveID: String) -> Bool {
        guard let context else { return false }
        return fetchMove(id: moveID, context: context)?.isShared == true
    }

    private func fetchMove(id: String, context: ModelContext) -> Move? {
        try? context.fetch(FetchDescriptor<Move>(predicate: #Predicate { $0.id == id })).first
    }

    /// Walk an NSManagedObject's attributes/relationships to find the Move
    /// it ultimately belongs to. Works for Move itself and every cascade
    /// type (Room/Item/Box/BoxType/BoxItem/ChecklistItem/ItemPhoto).
    private func owningMoveID(for obj: NSManagedObject) -> String? {
        let entityName = obj.entity.name ?? ""
        // Skip SwiftData's internal CloudKit mirror record types and any
        // non-app entities.
        guard ["Move", "Room", "Item", "ItemPhoto", "Box", "BoxType", "BoxItem", "ChecklistItem"].contains(entityName) else {
            return nil
        }

        if entityName == "Move" {
            return obj.value(forKey: "id") as? String
        }
        if entityName == "ItemPhoto" {
            if let item = obj.value(forKey: "item") as? NSManagedObject {
                return owningMoveID(for: item)
            }
            return nil
        }
        if entityName == "BoxItem" {
            if let box = obj.value(forKey: "box") as? NSManagedObject {
                return owningMoveID(for: box)
            }
            if let item = obj.value(forKey: "item") as? NSManagedObject {
                return owningMoveID(for: item)
            }
            return nil
        }
        // Room/Item/Box/BoxType/ChecklistItem all have a direct `move` relation.
        if let move = obj.value(forKey: "move") as? NSManagedObject {
            return move.value(forKey: "id") as? String
        }
        return nil
    }

    /// Read the `id` string from a SwiftData-backed NSManagedObject.
    private func idValue(of obj: NSManagedObject) -> String? {
        obj.value(forKey: "id") as? String
    }
}
