import Foundation

public enum DefaultRooms {
    public struct Entry: Sendable {
        public let label: String
        public let sides: [RoomKind]
    }

    public static let all: [Entry] = [
        .init(label: "Kitchen",         sides: [.origin, .destination]),
        .init(label: "Living room",     sides: [.origin, .destination]),
        .init(label: "Primary bedroom", sides: [.origin, .destination]),
        .init(label: "Bathroom",        sides: [.origin, .destination]),
        .init(label: "Office",          sides: [.origin, .destination]),
        .init(label: "Storage",         sides: [.destination]),
    ]
}

public enum BoxTagLabels {
    public static let map: [BoxTag: String] = [
        .fragile: "Fragile",
        .perishable: "Perishable",
        .liveAnimal: "Live animal",
    ]
}

public struct DefaultBoxType: Sendable {
    public let key: String
    public let label: String
    public let volumeCuFt: Decimal
    public let sortOrder: Int

    public init(key: String, label: String, volumeCuFt: Decimal, sortOrder: Int) {
        self.key = key
        self.label = label
        self.volumeCuFt = volumeCuFt
        self.sortOrder = sortOrder
    }
}

public enum DefaultBoxTypes {
    public static let all: [DefaultBoxType] = [
        .init(key: "small",     label: "Small (1.5 cuft)",     volumeCuFt: Decimal(string: "1.5")!, sortOrder: 10),
        .init(key: "medium",    label: "Medium (3.0 cuft)",    volumeCuFt: Decimal(string: "3.0")!, sortOrder: 20),
        .init(key: "large",     label: "Large (4.5 cuft)",     volumeCuFt: Decimal(string: "4.5")!, sortOrder: 30),
        .init(key: "dish_pack", label: "Dish pack (5.2 cuft)", volumeCuFt: Decimal(string: "5.2")!, sortOrder: 40),
        .init(key: "wardrobe",  label: "Wardrobe (11 cuft)",   volumeCuFt: Decimal(string: "11")!,  sortOrder: 50),
        .init(key: "tote",      label: "Tote (2.4 cuft)",      volumeCuFt: Decimal(string: "2.4")!, sortOrder: 60),
    ]
}
