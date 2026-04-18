import ClerkKit
import Foundation
import SwiftUI

@Observable
@MainActor
public final class AuthStore {
    public enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userId: String, email: String?)
    }

    public private(set) var state: State = .loading
    public private(set) var isBusy = false
    public private(set) var lastError: String?

    public init() {}

    public func bootstrap() async {
        Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
        do {
            _ = try await Clerk.shared.refreshEnvironment()
            _ = try await Clerk.shared.refreshClient()
        } catch {
            // Offline / cold boot — fall through and inspect cached state.
        }
        resolveState()
    }

    public func signIn(email: String, password: String) async {
        await run {
            _ = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: password)
        }
    }

    public func signUp(email: String, password: String, firstName: String?, lastName: String?) async {
        await run {
            let signUp = try await Clerk.shared.auth.signUp(
                emailAddress: email, password: password,
                firstName: firstName, lastName: lastName
            )
            if signUp.status == .missingRequirements {
                // Email code verification required.
                _ = try await signUp.sendEmailCode()
            }
        }
    }

    public func verifyEmailCode(_ code: String) async {
        guard let signUp = Clerk.shared.auth.currentSignUp else { return }
        await run { _ = try await signUp.verifyEmailCode(code) }
    }

    public func signOut() async {
        await run { try await Clerk.shared.auth.signOut() }
    }

    public func currentToken() async throws -> String? {
        try await Clerk.shared.auth.getToken()
    }

    // MARK: - Private

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        lastError = nil
        defer {
            isBusy = false
            resolveState()
        }
        do { try await work() }
        catch {
            lastError = error.localizedDescription
        }
    }

    private func resolveState() {
        if let session = Clerk.shared.session, let user = session.user {
            let email = user.emailAddresses.first(where: { $0.id == user.primaryEmailAddressId })?.emailAddress
                ?? user.emailAddresses.first?.emailAddress
            state = .signedIn(userId: user.id, email: email)
        } else {
            state = .signedOut
        }
    }
}
