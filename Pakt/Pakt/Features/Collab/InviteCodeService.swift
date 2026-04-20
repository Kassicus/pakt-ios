import CloudKit
import Foundation

/// Maps short human-friendly codes ↔ CKShare URLs via the CloudKit public DB.
///
/// Record type: `InviteCode` in the default zone of the public DB.
/// Fields: code (String, queryable), shareURL (String), moveName (String),
/// inviterName (String), expiresAt (Date), ownerUserRecordName (String).
///
/// Codes are consumed-on-first-accept and expire 10 minutes after creation.
/// The record type must be indexed on `code` in CloudKit Dashboard for
/// query performance; first-run in development creates the record type
/// automatically; schema must be promoted to Production before shipping.
public actor InviteCodeService {
    public enum InviteError: Error, LocalizedError {
        case notFound
        case expired
        case consumed
        case saveFailed(String)
        case transport(Error)

        public var errorDescription: String? {
            switch self {
            case .notFound:    return "That code doesn't match a live invite."
            case .expired:     return "This invite has expired. Ask the sender for a new code."
            case .consumed:    return "This invite has already been used."
            case .saveFailed(let m): return "Couldn't publish the invite: \(m)"
            case .transport(let e):  return e.localizedDescription
            }
        }
    }

    public struct InviteRecord: Sendable {
        public let code: String
        public let shareURL: URL
        public let moveName: String
        public let inviterName: String
        public let expiresAt: Date
    }

    public enum Fields {
        static let code = "code"
        static let shareURL = "shareURL"
        static let moveName = "moveName"
        static let inviterName = "inviterName"
        static let expiresAt = "expiresAt"
        static let ownerUserRecordName = "ownerUserRecordName"
    }

    public static let recordType = "InviteCode"
    public static let ttlSeconds: TimeInterval = 10 * 60

    private let container: CKContainer
    private var db: CKDatabase { container.publicCloudDatabase }

    public init(container: CKContainer = CKContainer(identifier: "iCloud.suchow.pakt")) {
        self.container = container
    }

    /// Create an invite record with a fresh short code. Retries on collision.
    public func create(
        shareURL: URL,
        moveName: String,
        inviterName: String
    ) async throws -> InviteRecord {
        let now = Date()
        let expiresAt = now.addingTimeInterval(Self.ttlSeconds)
        var ownerRecordName = "unknown"
        if let rid = try? await container.userRecordID() {
            ownerRecordName = rid.recordName
        }

        for _ in 0..<5 {
            let code = ShortCode.generateInviteCode()
            let record = CKRecord(recordType: Self.recordType)
            record[Fields.code] = code as CKRecordValue
            record[Fields.shareURL] = shareURL.absoluteString as CKRecordValue
            record[Fields.moveName] = moveName as CKRecordValue
            record[Fields.inviterName] = inviterName as CKRecordValue
            record[Fields.expiresAt] = expiresAt as CKRecordValue
            record[Fields.ownerUserRecordName] = ownerRecordName as CKRecordValue

            do {
                _ = try await db.save(record)
                return InviteRecord(
                    code: code,
                    shareURL: shareURL,
                    moveName: moveName,
                    inviterName: inviterName,
                    expiresAt: expiresAt
                )
            } catch let err as CKError where err.code == .serverRecordChanged {
                continue // collision, retry with a new code
            } catch {
                throw InviteError.saveFailed(error.localizedDescription)
            }
        }
        throw InviteError.saveFailed("Couldn't create a unique code after multiple tries.")
    }

    /// Look up a code. Returns nil if no record found; throws on transport
    /// errors. Expired records are reported via `.expired` error.
    public func resolve(code: String) async throws -> InviteRecord {
        let normalized = Self.normalize(code)
        let predicate = NSPredicate(format: "%K == %@", Fields.code, normalized)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1

        var fetched: CKRecord?
        op.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                fetched = record
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.queryResultBlock = { result in
                switch result {
                case .success: cont.resume(returning: ())
                case .failure(let e): cont.resume(throwing: InviteError.transport(e))
                }
            }
            db.add(op)
        }

        guard let record = fetched else { throw InviteError.notFound }
        guard let urlStr = record[Fields.shareURL] as? String,
              let url = URL(string: urlStr) else {
            throw InviteError.notFound
        }
        let expiresAt = (record[Fields.expiresAt] as? Date) ?? Date.distantPast
        if expiresAt < Date() {
            try? await consumeRecordID(record.recordID)
            throw InviteError.expired
        }
        return InviteRecord(
            code: normalized,
            shareURL: url,
            moveName: (record[Fields.moveName] as? String) ?? "",
            inviterName: (record[Fields.inviterName] as? String) ?? "",
            expiresAt: expiresAt
        )
    }

    /// Delete the code record after a successful accept, so it can't be reused.
    public func consume(code: String) async throws {
        let normalized = Self.normalize(code)
        let predicate = NSPredicate(format: "%K == %@", Fields.code, normalized)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1

        var foundID: CKRecord.ID?
        op.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                foundID = record.recordID
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.queryResultBlock = { _ in cont.resume(returning: ()) }
            db.add(op)
        }

        if let id = foundID {
            try await consumeRecordID(id)
        }
    }

    /// Best-effort cleanup of expired codes owned by current user. Called
    /// opportunistically when the user creates a new code.
    public func sweepExpired() async {
        let predicate = NSPredicate(format: "%K < %@", Fields.expiresAt, Date() as CVarArg)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 50

        var toDelete: [CKRecord.ID] = []
        op.recordMatchedBlock = { id, _ in toDelete.append(id) }
        _ = await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            op.queryResultBlock = { _ in cont.resume(returning: ()) }
            db.add(op)
        }
        for id in toDelete {
            _ = try? await db.deleteRecord(withID: id)
        }
    }

    private func consumeRecordID(_ id: CKRecord.ID) async throws {
        do {
            _ = try await db.deleteRecord(withID: id)
        } catch {
            throw InviteError.transport(error)
        }
    }

    /// Canonicalize user-entered codes: strip whitespace, uppercase, ensure
    /// the `PAKT-` prefix.
    public static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.hasPrefix("PAKT-") ? trimmed : "PAKT-" + trimmed
    }
}
