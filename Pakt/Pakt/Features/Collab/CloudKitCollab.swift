import CloudKit
import Foundation
import SwiftData
import SwiftUI

/// Orchestrates CloudKit sharing for Moves.
///
/// Owner side: `share(move:)` creates a per-Move custom zone, writes the
/// Move + cascade as CKRecords into it, and returns a `CKShare` whose URL can
/// be published.
///
/// Participant side: `acceptShare(with:)` accepts a CKShare metadata,
/// fetches all records from the shared zone, and materializes them into the
/// local SwiftData store.
///
/// This is an initial-snapshot implementation. A follow-up will add
/// subscriptions + live sync so edits on either device propagate to the
/// other. For now, participants see the Move as it was when they joined.
@Observable
@MainActor
public final class CloudKitCollab {
    public enum CollabError: Error, LocalizedError {
        case shareFailed(String)
        case fetchFailed(String)
        case noShareURL
        case notSignedIn

        public var errorDescription: String? {
            switch self {
            case .shareFailed(let m): return "Couldn't start sharing: \(m)"
            case .fetchFailed(let m): return "Couldn't sync the shared move: \(m)"
            case .noShareURL:         return "Share URL unavailable."
            case .notSignedIn:        return "Sign in with Apple first."
            }
        }
    }

    /// Info exposed to the inviter UI so it can display moveName + inviterName
    /// on the invite-code record.
    public struct ShareResult: Sendable {
        public let shareURL: URL
        public let moveName: String
    }

    private let container: CKContainer
    private var db: CKDatabase { container.privateCloudDatabase }

    public init(container: CKContainer = CKContainer(identifier: "iCloud.suchow.pakt")) {
        self.container = container
    }

    // MARK: - Owner

    /// Create a custom zone for this Move (if absent), upload all records,
    /// and wrap in a CKShare. Returns the share URL for publishing to
    /// InviteCodeService.
    public func share(move: Move, context: ModelContext) async throws -> ShareResult {
        let zoneID = MoveCKRecordMapper.zoneID(for: move.id)

        // Ensure custom zone exists.
        try await ensureZoneExists(zoneID)

        // If the local Move thinks it's already shared, verify the server
        // share is still valid. The server copy can go stale in two ways:
        //   1. The CKShare record was deleted out-of-band (Dashboard edit,
        //      stop-sharing on another device, container reset, etc.) — the
        //      local URL now points to nothing.
        //   2. An older build created the share with publicPermission=.none,
        //      which prevents code-based invitees from fetching metadata.
        //      Recreating as .readWrite is the fix.
        if move.cloudKitShareURLString != nil {
            if let existing = await fetchOwnerShare(for: move),
               existing.publicPermission == .readWrite,
               let url = existing.url {
                move.isShared = true
                move.cloudKitZoneName = zoneID.zoneName
                move.cloudKitShareURLString = url.absoluteString
                try? context.save()
                return ShareResult(shareURL: url, moveName: move.name)
            }

            // Stale or wrong-permission share. Delete it so the fresh save
            // below can create a clean one. Best-effort: ignore delete errors
            // (record may already be gone).
            if let existing = await fetchOwnerShare(for: move) {
                _ = try? await db.modifyRecords(
                    saving: [],
                    deleting: [existing.recordID]
                )
            }
            move.isShared = false
            move.cloudKitShareURLString = nil
        }

        // Build all CKRecords for the Move cascade.
        let recs = MoveCKRecordMapper.records(for: move)
        guard let root = recs.first(where: { $0.recordType == MoveCKRecordMapper.RecordType.move }) else {
            throw CollabError.shareFailed("No root Move record produced.")
        }

        // CloudKit requires the CKShare and its root record to be saved in the
        // same operation on first share creation. Save the share together with
        // the root record first, then upload the rest of the cascade.
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = move.name as CKRecordValue
        // Code-based invites: anyone with the share URL (resolved from the
        // short code) can join and edit. The CKShare URL is the true secret;
        // the short code in public DB acts as a short-lived, consumable
        // rotating pointer to it.
        share.publicPermission = .readWrite

        // The local `share` object does not have its URL populated — we must
        // read the server-returned CKShare from the save result.
        //
        // Save policy `.allKeys` overwrites any prior version of the root
        // record (harmless here — the Move data is the local source of truth
        // and we want to force it into this custom zone). The default
        // `.ifServerRecordUnchanged` causes atomic failures if the Move
        // recordID was ever touched in this zone before.
        let savedShare: CKShare
        do {
            let (savedResults, _) = try await db.modifyRecords(
                saving: [root, share],
                deleting: [],
                savePolicy: .allKeys
            )

            var foundShare: CKShare?
            var rootError: Error?
            var shareError: Error?
            for (recordID, result) in savedResults {
                switch result {
                case .success(let record):
                    if let s = record as? CKShare { foundShare = s }
                case .failure(let e):
                    if recordID == root.recordID {
                        rootError = e
                    } else {
                        shareError = e
                    }
                }
            }

            if let e = rootError {
                throw CollabError.shareFailed("Move record save failed: \(e.localizedDescription)")
            }
            if let e = shareError, foundShare == nil {
                throw CollabError.shareFailed("Share save failed: \(e.localizedDescription)")
            }
            guard let s = foundShare else {
                throw CollabError.shareFailed("Share save returned no share record.")
            }
            savedShare = s
        } catch let e as CollabError {
            throw e
        } catch let ckErr as CKError where ckErr.code == .partialFailure {
            // Batch rolled back due to per-record failures — surface them.
            let perItem = ckErr.partialErrorsByItemID ?? [:]
            if let rootErr = perItem[root.recordID] {
                throw CollabError.shareFailed("Move record: \(rootErr.localizedDescription)")
            }
            if let first = perItem.values.first {
                throw CollabError.shareFailed(first.localizedDescription)
            }
            throw CollabError.shareFailed(ckErr.localizedDescription)
        } catch {
            throw CollabError.shareFailed(error.localizedDescription)
        }

        // Now upload the rest of the cascade (everything except the root).
        let cascade = recs.filter { $0.recordID != root.recordID }
        if !cascade.isEmpty {
            do {
                try await saveRecords(cascade)
            } catch {
                throw CollabError.shareFailed(error.localizedDescription)
            }
        }

        guard let url = savedShare.url else { throw CollabError.noShareURL }

        // Persist share metadata onto the local Move.
        move.isShared = true
        move.cloudKitZoneName = zoneID.zoneName
        move.cloudKitShareURLString = url.absoluteString
        if let rid = try? await container.userRecordID() {
            move.ownerAppleUserId = rid.recordName
        }
        try? context.save()

        // Install owner-side zone subscription so edits from participants
        // trigger a silent push back to this device. Best-effort.
        try? await installZoneSubscription(zoneID: zoneID)

        return ShareResult(shareURL: url, moveName: move.name)
    }

    /// Fetch the writable CKShare from the owner's private DB. Returns nil
    /// if the move isn't shared or the share record can't be found.
    ///
    /// Prefer this over `fetchShareMetadata(url:)` for management operations —
    /// the metadata share is a read-only view and can't be modified/saved.
    public func fetchOwnerShare(for move: Move) async -> CKShare? {
        let zoneID = MoveCKRecordMapper.zoneID(for: move.id)
        let rootID = CKRecord.ID(recordName: move.id, zoneID: zoneID)
        let root: CKRecord
        do {
            root = try await db.record(for: rootID)
        } catch {
            return nil
        }
        guard let shareRef = root.share else { return nil }
        do {
            let shareRecord = try await db.record(for: shareRef.recordID)
            return shareRecord as? CKShare
        } catch {
            return nil
        }
    }

    /// Whether the current signed-in iCloud user is the owner of the share.
    /// Used by the UI to gate management actions.
    ///
    /// If you already got the share back from `fetchOwnerShare(for:)`,
    /// you're the owner by definition — that method fetches from the owner's
    /// private DB, which only the owner can read. We still double-check by
    /// comparing record names (userRecordID zone IDs can differ between
    /// `__defaultOwner__` literals and the live container's user ID, so a
    /// full CKRecord.ID equality is unreliable).
    public func isCurrentUserOwner(of share: CKShare) async -> Bool {
        guard let currentID = try? await container.userRecordID() else { return false }
        if let ownerRID = share.owner.userIdentity.userRecordID,
           ownerRID.recordName == currentID.recordName {
            return true
        }
        return false
    }

    /// Change a participant's permission (e.g. readOnly ↔ readWrite). The
    /// participant reference must come from the share you intend to save.
    public func updatePermission(
        for participant: CKShare.Participant,
        to permission: CKShare.ParticipantPermission,
        on share: CKShare
    ) async throws {
        participant.permission = permission
        do {
            _ = try await db.modifyRecords(
                saving: [share],
                deleting: [],
                savePolicy: .allKeys
            )
        } catch {
            throw CollabError.shareFailed(error.localizedDescription)
        }
    }

    /// Remove a participant from the share. The removed user will lose
    /// access on their next sync.
    public func removeParticipant(
        _ participant: CKShare.Participant,
        from share: CKShare
    ) async throws {
        share.removeParticipant(participant)
        do {
            _ = try await db.modifyRecords(
                saving: [share],
                deleting: [],
                savePolicy: .allKeys
            )
        } catch {
            throw CollabError.shareFailed(error.localizedDescription)
        }
    }

    /// Stop sharing the move entirely. Deletes the CKShare record from the
    /// owner's private DB; all participants lose access on their next sync.
    /// The move itself and its data remain intact on the owner's device.
    public func stopSharing(move: Move, context: ModelContext) async throws {
        if let share = await fetchOwnerShare(for: move) {
            do {
                _ = try await db.modifyRecords(
                    saving: [],
                    deleting: [share.recordID]
                )
            } catch {
                throw CollabError.shareFailed(error.localizedDescription)
            }
        }

        // Clean up the zone subscription + cached change token so stale
        // subscriptions don't keep firing for a zone we no longer care about.
        if let zoneName = move.cloudKitZoneName {
            await removeZoneSubscription(zoneName: zoneName)
        }

        move.isShared = false
        move.cloudKitShareURLString = nil
        move.ownerAppleUserId = nil
        try? context.save()
    }

    // MARK: - Participant

    /// Accept a CKShare URL (from an invite code resolution or from a
    /// continue-user-activity). Fetches the zone's records and materializes
    /// them into local SwiftData.
    public func acceptShare(at url: URL, context: ModelContext) async throws {
        let metadata = try await fetchShareMetadata(url: url)

        // Accept.
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
                op.acceptSharesResultBlock = { result in
                    switch result {
                    case .success: cont.resume(returning: ())
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
                container.add(op)
            }
        } catch {
            throw CollabError.fetchFailed(error.localizedDescription)
        }

        let zoneID = metadata.share.recordID.zoneID
        let sharedDB = container.sharedCloudDatabase
        let records = try await fetchAllRecords(in: zoneID, database: sharedDB)

        MoveCKRecordMapper.materialize(
            records: records,
            shareURL: url,
            ownerAppleUserId: metadata.ownerIdentity.userRecordID?.recordName,
            zoneName: zoneID.zoneName,
            context: context
        )
    }

    /// Accept via NSUserActivity payload (e.g. `onContinueUserActivity`).
    public func accept(activity: NSUserActivity, context: ModelContext) async {
        guard let metadata = activity.userInfo?[
            "CKShareMetadata"
        ] as? CKShare.Metadata,
              let url = metadata.share.url else { return }
        try? await acceptShare(at: url, context: context)
    }

    // MARK: - Private helpers

    private func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await db.modifyRecordZones(saving: [zone], deleting: [])
        } catch let err as CKError where err.code == .serverRecordChanged {
            // already exists, fine
        } catch {
            throw CollabError.shareFailed(error.localizedDescription)
        }
    }

    private func saveRecords(_ records: [CKRecord]) async throws {
        // Modify in batches of 100 to stay within CloudKit's per-operation limit.
        let chunks = stride(from: 0, to: records.count, by: 100).map {
            Array(records[$0 ..< min($0 + 100, records.count)])
        }
        for chunk in chunks {
            _ = try await db.modifyRecords(saving: chunk, deleting: [])
        }
    }

    private func fetchShareMetadata(url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { cont in
            let op = CKFetchShareMetadataOperation(shareURLs: [url])
            op.shouldFetchRootRecord = true

            var fetched: CKShare.Metadata?
            var perShareError: Error?
            op.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata):
                    fetched = metadata
                case .failure(let e):
                    perShareError = e
                }
            }
            op.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let m = fetched {
                        cont.resume(returning: m)
                    } else if let e = perShareError {
                        cont.resume(throwing: CollabError.fetchFailed(e.localizedDescription))
                    } else {
                        cont.resume(throwing: CollabError.fetchFailed("No metadata."))
                    }
                case .failure(let e):
                    cont.resume(throwing: e)
                }
            }
            container.add(op)
        }
    }

    private func fetchAllRecords(
        in zoneID: CKRecordZone.ID,
        database: CKDatabase
    ) async throws -> [CKRecord] {
        var collected: [CKRecord] = []
        var token: CKServerChangeToken?

        while true {
            let (records, newToken, moreComing) = try await fetchZoneChanges(
                zoneID: zoneID,
                token: token,
                database: database
            )
            collected.append(contentsOf: records)
            token = newToken
            if !moreComing { break }
        }
        return collected
    }

    // MARK: - Sync engine APIs (public for CloudKitSyncEngine)

    public enum Role: Sendable {
        case owner
        case participant
    }

    /// Determine whether the current device is the owner or participant of
    /// a shared move. Owner iff the CKShare is visible in our private DB.
    public func currentRole(for move: Move) async -> Role {
        await fetchOwnerShare(for: move) != nil ? .owner : .participant
    }

    /// Pick the correct database for reads/writes based on role. Owner uses
    /// their private DB (which contains the custom zone + CKShare). Participant
    /// uses the shared DB (their read/write view onto the owner's zone).
    public func database(for role: Role) -> CKDatabase {
        switch role {
        case .owner: return container.privateCloudDatabase
        case .participant: return container.sharedCloudDatabase
        }
    }

    /// Push a set of records to the given database. Batched in chunks of 100.
    /// Save policy `.allKeys` gives last-writer-wins semantics.
    public func pushRecords(_ records: [CKRecord], to database: CKDatabase) async throws {
        guard !records.isEmpty else { return }
        let chunks = stride(from: 0, to: records.count, by: 100).map {
            Array(records[$0 ..< min($0 + 100, records.count)])
        }
        for chunk in chunks {
            do {
                _ = try await database.modifyRecords(
                    saving: chunk,
                    deleting: [],
                    savePolicy: .allKeys
                )
            } catch {
                throw CollabError.shareFailed(error.localizedDescription)
            }
        }
    }

    /// Delete records from the given database. Silently ignores records that
    /// are already gone.
    public func deleteRecords(_ recordIDs: [CKRecord.ID], from database: CKDatabase) async throws {
        guard !recordIDs.isEmpty else { return }
        let chunks = stride(from: 0, to: recordIDs.count, by: 100).map {
            Array(recordIDs[$0 ..< min($0 + 100, recordIDs.count)])
        }
        for chunk in chunks {
            _ = try? await database.modifyRecords(saving: [], deleting: chunk)
        }
    }

    /// Fetch incremental changes for a zone. Returns inserted/updated records,
    /// deleted record IDs, the new server change token, and whether more
    /// pages remain.
    public func fetchZoneDelta(
        zoneID: CKRecordZone.ID,
        database: CKDatabase,
        token: CKServerChangeToken?
    ) async throws -> (records: [CKRecord], deletedIDs: [CKRecord.ID], newToken: CKServerChangeToken?, moreComing: Bool) {
        try await withCheckedThrowingContinuation { cont in
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = token

            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            var records: [CKRecord] = []
            var deleted: [CKRecord.ID] = []
            var finalToken: CKServerChangeToken?
            var moreComing = false

            op.recordWasChangedBlock = { _, result in
                if case .success(let r) = result {
                    records.append(r)
                }
            }
            op.recordWithIDWasDeletedBlock = { id, _ in
                deleted.append(id)
            }
            op.recordZoneChangeTokensUpdatedBlock = { _, newToken, _ in
                finalToken = newToken
            }
            op.recordZoneFetchResultBlock = { _, result in
                if case .success(let (t, _, more)) = result {
                    finalToken = t
                    moreComing = more
                }
            }
            op.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    cont.resume(returning: (records, deleted, finalToken, moreComing))
                case .failure(let e):
                    cont.resume(throwing: e)
                }
            }
            database.add(op)
        }
    }

    /// Fetch DB-scope changes: which zones have new data and the updated DB
    /// change token. Used by participants to discover new or changed zones.
    public func fetchDatabaseChanges(
        database: CKDatabase,
        token: CKServerChangeToken?
    ) async throws -> (changedZoneIDs: [CKRecordZone.ID], deletedZoneIDs: [CKRecordZone.ID], newToken: CKServerChangeToken?) {
        try await withCheckedThrowingContinuation { cont in
            let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)

            var changed: [CKRecordZone.ID] = []
            var deleted: [CKRecordZone.ID] = []
            var finalToken: CKServerChangeToken?

            op.recordZoneWithIDChangedBlock = { id in changed.append(id) }
            op.recordZoneWithIDWasDeletedBlock = { id in deleted.append(id) }
            op.changeTokenUpdatedBlock = { t in finalToken = t }
            op.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success(let (t, _)):
                    finalToken = t
                    cont.resume(returning: (changed, deleted, finalToken))
                case .failure(let e):
                    cont.resume(throwing: e)
                }
            }
            database.add(op)
        }
    }

    /// Install a zone subscription so the owner gets silent push on any
    /// change to a shared-move zone. Idempotent — safe to call repeatedly.
    public func installZoneSubscription(zoneID: CKRecordZone.ID) async throws {
        guard !CloudKitChangeTokens.hasInstalledZoneSubscription(zoneName: zoneID.zoneName) else { return }

        let sub = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "zone-sub-\(zoneID.zoneName)")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        do {
            _ = try await db.modifySubscriptions(saving: [sub], deleting: [])
            CloudKitChangeTokens.markZoneSubscriptionInstalled(zoneName: zoneID.zoneName)
        } catch let err as CKError where err.code == .serverRejectedRequest {
            // Already exists — mark as installed and move on.
            CloudKitChangeTokens.markZoneSubscriptionInstalled(zoneName: zoneID.zoneName)
        } catch {
            throw CollabError.shareFailed(error.localizedDescription)
        }
    }

    /// Install a single database-wide subscription so participants get silent
    /// push on any change across any shared zone. Idempotent.
    public func installSharedDBSubscription() async throws {
        guard !CloudKitChangeTokens.hasInstalledSharedDBSubscription() else { return }

        let sub = CKDatabaseSubscription(subscriptionID: "shared-db-sub")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        do {
            _ = try await container.sharedCloudDatabase.modifySubscriptions(saving: [sub], deleting: [])
            CloudKitChangeTokens.markSharedDBSubscriptionInstalled()
        } catch let err as CKError where err.code == .serverRejectedRequest {
            CloudKitChangeTokens.markSharedDBSubscriptionInstalled()
        } catch {
            throw CollabError.shareFailed(error.localizedDescription)
        }
    }

    /// Remove the zone subscription when the owner stops sharing a move.
    public func removeZoneSubscription(zoneName: String) async {
        let subID = "zone-sub-\(zoneName)"
        _ = try? await db.modifySubscriptions(saving: [], deleting: [subID])
        CloudKitChangeTokens.clearZoneSubscription(zoneName: zoneName)
        CloudKitChangeTokens.setZoneToken(nil, for: zoneName)
    }

    private func fetchZoneChanges(
        zoneID: CKRecordZone.ID,
        token: CKServerChangeToken?,
        database: CKDatabase
    ) async throws -> ([CKRecord], CKServerChangeToken?, Bool) {
        try await withCheckedThrowingContinuation { cont in
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = token

            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            var records: [CKRecord] = []
            var finalToken: CKServerChangeToken?
            var moreComing = false

            op.recordWasChangedBlock = { _, result in
                if case .success(let r) = result {
                    records.append(r)
                }
            }
            op.recordZoneChangeTokensUpdatedBlock = { _, newToken, _ in
                finalToken = newToken
            }
            op.recordZoneFetchResultBlock = { _, result in
                if case .success(let (t, _, more)) = result {
                    finalToken = t
                    moreComing = more
                }
            }
            op.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    cont.resume(returning: (records, finalToken, moreComing))
                case .failure(let e):
                    cont.resume(throwing: e)
                }
            }
            database.add(op)
        }
    }
}
