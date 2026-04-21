import Foundation

/// Generic escape hatch for bridging a non-Sendable value across an isolation
/// boundary when the caller can guarantee safe handoff (typically because the
/// value is read-only after the hop, or the hop goes directly to the
/// single-threaded MainActor).
///
/// Use sparingly — a true Sendable design is always preferable.
final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
