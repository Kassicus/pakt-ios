import Foundation
import PaktCore

public struct MoveListEntry: Codable, Hashable, Sendable, Identifiable {
    public let move: Move
    public let role: MoveRole

    public var id: String { move.id }
}

public extension Endpoint where Response == [MoveListEntry] {
    static func listMoves() -> Endpoint<[MoveListEntry]> {
        Endpoint(path: "/v1/moves")
    }
}

public extension Endpoint where Response == MoveListEntry {
    static func getMove(id: String) -> Endpoint<MoveListEntry> {
        Endpoint(path: "/v1/moves/\(id)")
    }
}
