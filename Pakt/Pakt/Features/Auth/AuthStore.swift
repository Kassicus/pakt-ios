import AuthenticationServices
import CloudKit
import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
public final class AuthStore {
    public enum State: Equatable {
        case loading
        case guest
        case reconciling(appleUserId: String, email: String?)
        case signedIn(appleUserId: String, email: String? = nil)
    }

    /// Raised by `handleAuthorization` when the user previously created local
    /// (guest) data AND an iCloud-private-DB mirror for this Apple ID already
    /// has data. The UI must present MergeDecisionSheet and then call
    /// `resumeAfterMergeDecision`.
    public private(set) var mergeDecisionRequired = false
    public private(set) var state: State = .loading
    public private(set) var lastError: String?

    private static let kAppleUserId = "appleUserId"

    public init() {}

    /// Runs at app launch. Restores the last Apple user ID from Keychain and
    /// confirms with Apple that the credential is still valid.
    public func bootstrap() async {
        guard let userId = Keychain.getString(Self.kAppleUserId) else {
            state = .guest
            return
        }
        do {
            let credentialState = try await ASAuthorizationAppleIDProvider()
                .credentialState(forUserID: userId)
            switch credentialState {
            case .authorized:
                state = .signedIn(appleUserId: userId, email: nil)
            case .revoked, .notFound, .transferred:
                Keychain.setString(nil, for: Self.kAppleUserId)
                state = .guest
            @unknown default:
                state = .guest
            }
        } catch {
            state = .signedIn(appleUserId: userId, email: nil)
        }
    }

    /// Called by SignInWithAppleButton on success.
    ///
    /// If the user had guest-created local data AND the Apple ID's iCloud
    /// private DB already has Pakt data on it, we enter `.reconciling` and set
    /// `mergeDecisionRequired = true` so the UI can ask before committing.
    /// Otherwise we transition directly to `.signedIn`.
    public func handleAuthorization(
        _ authorization: ASAuthorization,
        context: ModelContext
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            lastError = "Unexpected credential type."
            return
        }
        let userId = credential.user
        let email = credential.email
        let name = credential.fullName.flatMap { Self.format($0) }
        Keychain.setString(userId, for: Self.kAppleUserId)
        upsertUser(appleUserId: userId, name: name, email: email, context: context)
        lastError = nil

        let hasLocalGuestData = Self.hasAnyMoves(in: context)
        state = .reconciling(appleUserId: userId, email: email)

        Task { [weak self] in
            let hasRemote = await Self.remotePrivateDBHasData()
            await MainActor.run {
                guard let self else { return }
                if hasLocalGuestData && hasRemote {
                    self.mergeDecisionRequired = true
                } else {
                    self.state = .signedIn(appleUserId: userId, email: email)
                }
            }
        }
    }

    /// Called by MergeDecisionSheet once the user has chosen a path.
    ///
    /// - keepLocal: local-created data stays; iCloud remote pulls in alongside
    ///   and SwiftData handles duplicates.
    /// - startFresh: wipe local SwiftData for app models and trust iCloud.
    public func resumeAfterMergeDecision(keepLocal: Bool, context: ModelContext) {
        guard case .reconciling(let userId, let email) = state else { return }
        mergeDecisionRequired = false
        if !keepLocal {
            Self.wipeLocalStore(context: context)
        }
        state = .signedIn(appleUserId: userId, email: email)
    }

    public func handleAuthorizationError(_ error: Error) {
        if (error as NSError).domain == ASAuthorizationError.errorDomain,
           (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            return // user cancelled — silent
        }
        lastError = error.localizedDescription
    }

    /// Sign out — preserves local data, returns to guest mode so the user can
    /// keep using the app offline.
    public func signOut() {
        Keychain.setString(nil, for: Self.kAppleUserId)
        state = .guest
    }

    // MARK: - Private

    private func upsertUser(appleUserId: String, name: String?, email: String?, context: ModelContext) {
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.appleUserId == appleUserId })
        if let existing = try? context.fetch(descriptor).first {
            if let name, existing.displayName == nil { existing.displayName = name }
            if let email, existing.email == nil { existing.email = email }
            existing.signedInAt = Date()
        } else {
            context.insert(User(appleUserId: appleUserId, displayName: name, email: email))
        }
    }

    private static func format(_ name: PersonNameComponents) -> String? {
        let formatted = PersonNameComponentsFormatter().string(from: name)
        return formatted.isEmpty ? nil : formatted
    }

    private static func hasAnyMoves(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Move>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    /// Best-effort check: does the signed-in Apple ID's private iCloud DB
    /// already have Pakt records pushed by another device? SwiftData's CloudKit
    /// mirror uses record types prefixed `CD_`. We query for `CD_Move` in the
    /// private DB. Failures (no network, permission issues) yield `false` —
    /// i.e. "assume no remote data" so we don't block sign-in on transient
    /// errors.
    private static func remotePrivateDBHasData() async -> Bool {
        let container = CKContainer(identifier: "iCloud.suchow.pakt")
        let db = container.privateCloudDatabase
        let query = CKQuery(recordType: "CD_Move", predicate: NSPredicate(value: true))
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1

        return await withCheckedContinuation { cont in
            var found = false
            op.recordMatchedBlock = { _, result in
                if case .success = result { found = true }
            }
            op.queryResultBlock = { _ in
                cont.resume(returning: found)
            }
            db.add(op)
        }
    }

    /// Delete every row of app model types from the local SwiftData store.
    /// Called by "Start fresh" on merge; iCloud will re-seed from remote.
    private static func wipeLocalStore(context: ModelContext) {
        do {
            try context.delete(model: Move.self)
            try context.delete(model: Room.self)
            try context.delete(model: Item.self)
            try context.delete(model: ItemPhoto.self)
            try context.delete(model: Box.self)
            try context.delete(model: BoxType.self)
            try context.delete(model: BoxItem.self)
            try context.delete(model: ChecklistItem.self)
            try context.save()
        } catch {
            // Non-fatal; iCloud pull will still proceed.
        }
    }
}
