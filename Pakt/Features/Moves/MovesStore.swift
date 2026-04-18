import Foundation
import PaktCore
import SwiftUI

@Observable
@MainActor
public final class MovesStore {
    public enum State: Equatable {
        case idle
        case loading
        case loaded([MoveListEntry])
        case failed(String)

        var entries: [MoveListEntry] {
            if case .loaded(let v) = self { return v } else { return [] }
        }
    }

    public private(set) var state: State = .idle
    private let api: PaktAPI

    public init(api: PaktAPI) {
        self.api = api
    }

    public func load() async {
        state = .loading
        do {
            let entries = try await api.send(.listMoves())
            state = .loaded(entries)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func refresh() async { await load() }
}
