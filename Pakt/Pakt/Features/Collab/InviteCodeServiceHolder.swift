import Foundation

/// SwiftUI environments don't carry actors directly. Wrap the service in an
/// `@Observable` holder so views can access it via `@Environment`.
@Observable
@MainActor
public final class InviteCodeServiceHolder {
    public let service: InviteCodeService

    public init(service: InviteCodeService = InviteCodeService()) {
        self.service = service
    }
}
