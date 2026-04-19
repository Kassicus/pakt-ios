import Foundation

public struct ItemCategory: Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    public let volumeCuFtPerItem: Double
    public let weightLbsPerItem: Double
    public let recommendedBoxType: RecommendedBoxType
    public let fragile: Bool
    public let sortOrder: Int

    public init(
        id: String, label: String,
        volumeCuFtPerItem: Double, weightLbsPerItem: Double,
        recommendedBoxType: RecommendedBoxType, fragile: Bool, sortOrder: Int
    ) {
        self.id = id
        self.label = label
        self.volumeCuFtPerItem = volumeCuFtPerItem
        self.weightLbsPerItem = weightLbsPerItem
        self.recommendedBoxType = recommendedBoxType
        self.fragile = fragile
        self.sortOrder = sortOrder
    }
}

/// Mirror of the web app's `item_categories` seed rows. Kept as a static
/// table because a single-operator iOS app doesn't need runtime overrides.
public enum ItemCategories {
    public static let all: [ItemCategory] = [
        .init(id: "cat_books",                 label: "Books",                    volumeCuFtPerItem: 0.150, weightLbsPerItem:  1.80, recommendedBoxType: .small,    fragile: false, sortOrder: 10),
        .init(id: "cat_documents_files",       label: "Documents & files",        volumeCuFtPerItem: 0.300, weightLbsPerItem:  4.00, recommendedBoxType: .small,    fragile: false, sortOrder: 20),
        .init(id: "cat_tools",                 label: "Tools",                    volumeCuFtPerItem: 0.300, weightLbsPerItem:  3.00, recommendedBoxType: .small,    fragile: false, sortOrder: 30),
        .init(id: "cat_kitchen_dishes",        label: "Dishes & glassware",       volumeCuFtPerItem: 0.250, weightLbsPerItem:  1.20, recommendedBoxType: .dishPack, fragile: true,  sortOrder: 40),
        .init(id: "cat_kitchen_cookware",      label: "Pots & pans",              volumeCuFtPerItem: 0.600, weightLbsPerItem:  3.00, recommendedBoxType: .medium,   fragile: false, sortOrder: 50),
        .init(id: "cat_kitchen_small_appliance", label: "Small kitchen appliances", volumeCuFtPerItem: 1.500, weightLbsPerItem:  6.00, recommendedBoxType: .medium,   fragile: true,  sortOrder: 60),
        .init(id: "cat_kitchen_pantry",        label: "Pantry / food",            volumeCuFtPerItem: 0.200, weightLbsPerItem:  1.50, recommendedBoxType: .small,    fragile: false, sortOrder: 70),
        .init(id: "cat_clothes_hanging",       label: "Hanging clothes",          volumeCuFtPerItem: 0.400, weightLbsPerItem:  0.50, recommendedBoxType: .wardrobe, fragile: false, sortOrder: 80),
        .init(id: "cat_clothes_folded",        label: "Folded clothes",           volumeCuFtPerItem: 0.250, weightLbsPerItem:  0.80, recommendedBoxType: .large,    fragile: false, sortOrder: 90),
        .init(id: "cat_shoes",                 label: "Shoes",                    volumeCuFtPerItem: 0.200, weightLbsPerItem:  1.50, recommendedBoxType: .medium,   fragile: false, sortOrder: 100),
        .init(id: "cat_linens_bedding",        label: "Bedding & pillows",        volumeCuFtPerItem: 0.600, weightLbsPerItem:  1.50, recommendedBoxType: .large,    fragile: false, sortOrder: 110),
        .init(id: "cat_towels",                label: "Towels",                   volumeCuFtPerItem: 0.300, weightLbsPerItem:  1.00, recommendedBoxType: .large,    fragile: false, sortOrder: 120),
        .init(id: "cat_electronics_small",     label: "Small electronics",        volumeCuFtPerItem: 0.400, weightLbsPerItem:  2.00, recommendedBoxType: .medium,   fragile: true,  sortOrder: 130),
        .init(id: "cat_electronics_monitor",   label: "Monitor / display",        volumeCuFtPerItem: 3.000, weightLbsPerItem: 15.00, recommendedBoxType: .medium,   fragile: true,  sortOrder: 140),
        .init(id: "cat_decor_small",           label: "Small décor",              volumeCuFtPerItem: 0.300, weightLbsPerItem:  1.00, recommendedBoxType: .medium,   fragile: true,  sortOrder: 150),
        .init(id: "cat_decor_art_framed",      label: "Framed art / mirror",      volumeCuFtPerItem: 2.000, weightLbsPerItem:  5.00, recommendedBoxType: .none,     fragile: true,  sortOrder: 160),
        .init(id: "cat_toys",                  label: "Toys & games",             volumeCuFtPerItem: 0.500, weightLbsPerItem:  1.00, recommendedBoxType: .medium,   fragile: false, sortOrder: 170),
        .init(id: "cat_furniture_small",       label: "Small furniture",          volumeCuFtPerItem: 8.000, weightLbsPerItem: 30.00, recommendedBoxType: .none,     fragile: false, sortOrder: 180),
        .init(id: "cat_furniture_medium",      label: "Medium furniture",         volumeCuFtPerItem: 20.000, weightLbsPerItem: 80.00, recommendedBoxType: .none,    fragile: false, sortOrder: 190),
        .init(id: "cat_furniture_large",       label: "Large furniture",          volumeCuFtPerItem: 50.000, weightLbsPerItem: 180.00, recommendedBoxType: .none,   fragile: false, sortOrder: 200),
        .init(id: "cat_mattress_queen",        label: "Mattress (queen)",         volumeCuFtPerItem: 35.000, weightLbsPerItem: 65.00, recommendedBoxType: .none,    fragile: false, sortOrder: 210),
        .init(id: "cat_mattress_king",         label: "Mattress (king)",          volumeCuFtPerItem: 45.000, weightLbsPerItem: 80.00, recommendedBoxType: .none,    fragile: false, sortOrder: 220),
        .init(id: "cat_other",                 label: "Other",                    volumeCuFtPerItem: 0.500, weightLbsPerItem:  2.00, recommendedBoxType: .medium,   fragile: false, sortOrder: 999),
    ]

    public static let byId: [String: ItemCategory] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    public static func lookup(_ id: String?) -> ItemCategory? {
        guard let id else { return nil }
        return byId[id]
    }

    public static let defaultCategoryId = "cat_other"
}
