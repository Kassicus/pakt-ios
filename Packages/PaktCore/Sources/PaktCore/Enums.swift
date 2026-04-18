import Foundation

public enum MoveStatus: String, Codable, Sendable, CaseIterable {
    case planning
    case packing
    case inTransit = "in_transit"
    case unpacking
    case done
}

public enum RoomKind: String, Codable, Sendable, CaseIterable {
    case origin
    case destination
}

public enum Disposition: String, Codable, Sendable, CaseIterable {
    case undecided
    case moving
    case storage
    case donate
    case trash
    case sold
}

public enum Fragility: String, Codable, Sendable, CaseIterable {
    case normal
    case fragile
    case veryFragile = "very_fragile"
}

public enum BoxStatus: String, Codable, Sendable, CaseIterable {
    case empty
    case packing
    case sealed
    case loaded
    case inTransit = "in_transit"
    case delivered
    case unpacked
}

public enum ChecklistCategory: String, Codable, Sendable, CaseIterable {
    case d30 = "30d"
    case w2 = "2w"
    case week
    case day
    case after
}

public enum MoveRole: String, Codable, Sendable, CaseIterable, Comparable {
    case helper
    case editor
    case owner

    private var rank: Int {
        switch self {
        case .helper: return 1
        case .editor: return 2
        case .owner: return 3
        }
    }

    public static func < (lhs: MoveRole, rhs: MoveRole) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum BoxTag: String, Codable, Sendable, CaseIterable {
    case fragile
    case perishable
    case liveAnimal = "live_animal"
}

public enum RecommendedBoxType: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case large
    case dishPack = "dish_pack"
    case wardrobe
    case tote
    case none
}

public enum WouldBuyAgain: String, Codable, Sendable, CaseIterable {
    case yes
    case no
    case unsure
}
