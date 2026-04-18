import Foundation
import PaktCore
import SwiftData

// SwiftData + CloudKit requires:
//  • all properties have defaults (or are optional)
//  • no @Attribute(.unique)
//  • relationships are optional, and have inverses
// Enum rawValues are stored as strings; match the PaktCore raw values so
// reasoning about data parity with the web schema stays trivial.

@Model public final class User {
    public var appleUserId: String = ""
    public var displayName: String?
    public var email: String?
    public var signedInAt: Date = Date()

    public init(appleUserId: String, displayName: String? = nil, email: String? = nil) {
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.email = email
        self.signedInAt = Date()
    }
}

@Model public final class Move {
    public var id: String = ""
    public var name: String = ""
    public var originAddress: String?
    public var destinationAddress: String?
    public var plannedMoveDate: Date?
    public var statusRaw: String = MoveStatus.planning.rawValue
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Room.move)  public var rooms: [Room]?
    @Relationship(deleteRule: .cascade, inverse: \Item.move)  public var items: [Item]?
    @Relationship(deleteRule: .cascade, inverse: \Box.move)   public var boxes: [Box]?
    @Relationship(deleteRule: .cascade, inverse: \BoxType.move) public var boxTypes: [BoxType]?
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.move) public var checklist: [ChecklistItem]?

    public var status: MoveStatus {
        get { MoveStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: String = ShortCode.generateId(.move),
        name: String,
        originAddress: String? = nil,
        destinationAddress: String? = nil,
        plannedMoveDate: Date? = nil,
        status: MoveStatus = .planning
    ) {
        self.id = id
        self.name = name
        self.originAddress = originAddress
        self.destinationAddress = destinationAddress
        self.plannedMoveDate = plannedMoveDate
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model public final class Room {
    public var id: String = ""
    public var kindRaw: String = RoomKind.origin.rawValue
    public var label: String = ""
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var move: Move?
    public var parentRoom: Room?
    @Relationship(deleteRule: .nullify, inverse: \Room.parentRoom) public var childRooms: [Room]?

    public var kind: RoomKind {
        get { RoomKind(rawValue: kindRaw) ?? .origin }
        set { kindRaw = newValue.rawValue }
    }

    public init(
        id: String = ShortCode.generateId(.room),
        move: Move?,
        kind: RoomKind,
        label: String,
        parentRoom: Room? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.move = move
        self.kindRaw = kind.rawValue
        self.label = label
        self.parentRoom = parentRoom
        self.sortOrder = sortOrder
    }
}

@Model public final class BoxType {
    public var id: String = ""
    public var key: String?
    public var label: String = ""
    public var volumeCuFt: Double?
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public var move: Move?
    @Relationship(deleteRule: .deny, inverse: \Box.boxType) public var boxes: [Box]?

    public init(
        id: String = ShortCode.generateId(.boxType),
        move: Move?,
        key: String? = nil,
        label: String,
        volumeCuFt: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.move = move
        self.key = key
        self.label = label
        self.volumeCuFt = volumeCuFt
        self.sortOrder = sortOrder
    }
}

@Model public final class Item {
    public var id: String = ""
    public var name: String = ""
    public var categoryId: String?
    public var dispositionRaw: String = Disposition.undecided.rawValue
    public var fragilityRaw: String = Fragility.normal.rawValue
    public var quantity: Int = 1
    public var estimatedValueUsd: Double?
    public var volumeCuFtOverride: Double?
    public var weightLbsOverride: Double?
    public var notes: String?
    public var decisionLastUsedMonths: Int?
    public var decisionReplacementCostUsd: Double?
    public var decisionSentimental: Bool?
    public var decisionWouldBuyAgainRaw: String?
    public var decisionScore: Double?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public var move: Move?
    public var sourceRoom: Room?
    public var destinationRoom: Room?
    @Relationship(deleteRule: .cascade, inverse: \ItemPhoto.item) public var photos: [ItemPhoto]?
    @Relationship(deleteRule: .cascade, inverse: \BoxItem.item)   public var boxItems: [BoxItem]?

    public var disposition: Disposition {
        get { Disposition(rawValue: dispositionRaw) ?? .undecided }
        set { dispositionRaw = newValue.rawValue }
    }

    public var fragility: Fragility {
        get { Fragility(rawValue: fragilityRaw) ?? .normal }
        set { fragilityRaw = newValue.rawValue }
    }

    public var wouldBuyAgain: WouldBuyAgain? {
        get { decisionWouldBuyAgainRaw.flatMap(WouldBuyAgain.init(rawValue:)) }
        set { decisionWouldBuyAgainRaw = newValue?.rawValue }
    }

    public init(
        id: String = ShortCode.generateId(.item),
        move: Move?,
        name: String,
        sourceRoom: Room? = nil,
        destinationRoom: Room? = nil,
        categoryId: String? = nil,
        quantity: Int = 1,
        disposition: Disposition = .undecided,
        fragility: Fragility = .normal
    ) {
        self.id = id
        self.move = move
        self.name = name
        self.sourceRoom = sourceRoom
        self.destinationRoom = destinationRoom
        self.categoryId = categoryId
        self.quantity = quantity
        self.dispositionRaw = disposition.rawValue
        self.fragilityRaw = fragility.rawValue
    }
}

@Model public final class ItemPhoto {
    public var id: String = ""
    @Attribute(.externalStorage) public var data: Data?
    public var width: Int?
    public var height: Int?
    public var byteSize: Int?
    public var contentType: String?
    public var createdAt: Date = Date()

    public var item: Item?

    public init(
        id: String = ShortCode.generateId(.photo),
        item: Item?,
        data: Data?,
        width: Int? = nil,
        height: Int? = nil,
        byteSize: Int? = nil,
        contentType: String? = nil
    ) {
        self.id = id
        self.item = item
        self.data = data
        self.width = width
        self.height = height
        self.byteSize = byteSize
        self.contentType = contentType
    }
}

@Model public final class Box {
    public var id: String = ""
    public var shortCode: String = ""
    public var statusRaw: String = BoxStatus.empty.rawValue
    public var tagsRaw: [String] = []
    public var weightLbsActual: Double?
    public var notes: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public var move: Move?
    public var boxType: BoxType?
    public var sourceRoom: Room?
    public var destinationRoom: Room?
    @Relationship(deleteRule: .cascade, inverse: \BoxItem.box) public var boxItems: [BoxItem]?

    public var status: BoxStatus {
        get { BoxStatus(rawValue: statusRaw) ?? .empty }
        set { statusRaw = newValue.rawValue }
    }

    public var tags: [BoxTag] {
        get { tagsRaw.compactMap(BoxTag.init(rawValue:)) }
        set { tagsRaw = newValue.map(\.rawValue) }
    }

    public init(
        id: String = ShortCode.generateId(.box),
        move: Move?,
        shortCode: String = ShortCode.generateBoxShortCode(),
        boxType: BoxType?,
        sourceRoom: Room? = nil,
        destinationRoom: Room? = nil,
        status: BoxStatus = .empty,
        tags: [BoxTag] = []
    ) {
        self.id = id
        self.move = move
        self.shortCode = shortCode
        self.boxType = boxType
        self.sourceRoom = sourceRoom
        self.destinationRoom = destinationRoom
        self.statusRaw = status.rawValue
        self.tagsRaw = tags.map(\.rawValue)
    }
}

@Model public final class BoxItem {
    public var id: String = ""
    public var quantity: Int = 1
    public var createdAt: Date = Date()

    public var box: Box?
    public var item: Item?

    public init(
        id: String = ShortCode.generateId(.boxItem),
        box: Box?,
        item: Item?,
        quantity: Int = 1
    ) {
        self.id = id
        self.box = box
        self.item = item
        self.quantity = quantity
    }
}

@Model public final class ChecklistItem {
    public var id: String = ""
    public var text: String = ""
    public var categoryRaw: String = ChecklistCategory.week.rawValue
    public var doneAt: Date?
    public var sortOrder: Int = 0
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var move: Move?

    public var category: ChecklistCategory {
        get { ChecklistCategory(rawValue: categoryRaw) ?? .week }
        set { categoryRaw = newValue.rawValue }
    }

    public var isDone: Bool { doneAt != nil }

    public init(
        id: String = ShortCode.generateId(.checklist),
        move: Move?,
        text: String,
        category: ChecklistCategory,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.move = move
        self.text = text
        self.categoryRaw = category.rawValue
        self.sortOrder = sortOrder
    }
}

public enum AppSchema {
    public static let models: [any PersistentModel.Type] = [
        User.self, Move.self, Room.self, BoxType.self,
        Item.self, ItemPhoto.self, Box.self, BoxItem.self, ChecklistItem.self,
    ]
}
