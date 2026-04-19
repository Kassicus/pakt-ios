import SwiftUI

extension BoxStatus: Comparable {
    private var rank: Int {
        switch self {
        case .empty:     return 0
        case .packing:   return 1
        case .sealed:    return 2
        case .loaded:    return 3
        case .inTransit: return 4
        case .delivered: return 5
        case .unpacked:  return 6
        }
    }

    public static func < (lhs: BoxStatus, rhs: BoxStatus) -> Bool {
        lhs.rank < rhs.rank
    }

    public static let ordered: [BoxStatus] = [
        .empty, .packing, .sealed, .loaded, .inTransit, .delivered, .unpacked,
    ]

    public var label: String {
        switch self {
        case .empty:     return "Empty"
        case .packing:   return "Packing"
        case .sealed:    return "Sealed"
        case .loaded:    return "Loaded"
        case .inTransit: return "In transit"
        case .delivered: return "Delivered"
        case .unpacked:  return "Unpacked"
        }
    }

    public var tone: PaktBadgeTone {
        switch self {
        case .empty, .packing:      return .outline
        case .sealed, .loaded:      return .secondary
        case .inTransit, .delivered: return .default
        case .unpacked:             return .ghost
        }
    }

    public var nextStatus: BoxStatus? {
        guard let index = Self.ordered.firstIndex(of: self),
              index + 1 < Self.ordered.count
        else { return nil }
        return Self.ordered[index + 1]
    }

    public var previousStatus: BoxStatus? {
        guard let index = Self.ordered.firstIndex(of: self),
              index > 0
        else { return nil }
        return Self.ordered[index - 1]
    }
}

extension BoxTag {
    public var label: String { BoxTagLabels.map[self] ?? rawValue }
}
