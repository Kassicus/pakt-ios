import AuthenticationServices
import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
public final class AuthStore {
    public enum State: Equatable {
        case loading
        case signedOut
        case signedIn(appleUserId: String)
    }

    public private(set) var state: State = .loading
    public private(set) var lastError: String?

    private static let kAppleUserId = "appleUserId"

    public init() {}

    /// Runs at app launch. Restores the last Apple user ID from Keychain and
    /// confirms with Apple that the credential is still valid.
    public func bootstrap() async {
        guard let userId = Keychain.getString(Self.kAppleUserId) else {
            state = .signedOut
            return
        }
        do {
            let credentialState = try await ASAuthorizationAppleIDProvider()
                .credentialState(forUserID: userId)
            switch credentialState {
            case .authorized:
                state = .signedIn(appleUserId: userId)
            case .revoked, .notFound, .transferred:
                Keychain.setString(nil, for: Self.kAppleUserId)
                state = .signedOut
            @unknown default:
                state = .signedOut
            }
        } catch {
            state = .signedIn(appleUserId: userId)
        }
    }

    /// Called by SignInWithAppleButton on success.
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
        state = .signedIn(appleUserId: userId)
        lastError = nil
    }

    public func handleAuthorizationError(_ error: Error) {
        if (error as NSError).domain == ASAuthorizationError.errorDomain,
           (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            return // user cancelled — silent
        }
        lastError = error.localizedDescription
    }

    public func signOut() {
        Keychain.setString(nil, for: Self.kAppleUserId)
        state = .signedOut
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
}
