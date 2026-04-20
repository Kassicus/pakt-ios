import CloudKit
import Foundation
import SwiftData

/// Pure bi-directional mapping between SwiftData Move (and its cascade) and
/// CKRecords in a per-Move custom zone.
///
/// Each shared Move gets its own zone named `move-<moveId>` in the owner's
/// private DB. The Move itself is the zone's root record; rooms, items,
/// boxes, boxTypes, boxItems, and checklist items become child records
/// with a `moveRef` back to the Move root. Photos become CKAssets.
enum MoveCKRecordMapper {
    enum RecordType {
        static let move = "Move"
        static let room = "Room"
        static let item = "Item"
        static let itemPhoto = "ItemPhoto"
        static let box = "Box"
        static let boxType = "BoxType"
        static let boxItem = "BoxItem"
        static let checklist = "ChecklistItem"
    }

    static func zoneID(for moveId: String) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "move-\(moveId)", ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Move → CKRecords

    /// Serialize a Move and all its cascade records for upload to a custom zone.
    /// Returns the full list; caller saves them in one modify operation.
    static func records(for move: Move) -> [CKRecord] {
        let zone = zoneID(for: move.id)
        var out: [CKRecord] = []

        // Move root.
        let moveRec = CKRecord(
            recordType: RecordType.move,
            recordID: CKRecord.ID(recordName: move.id, zoneID: zone)
        )
        moveRec["name"] = move.name as CKRecordValue
        moveRec["originAddress"] = move.originAddress as CKRecordValue?
        moveRec["destinationAddress"] = move.destinationAddress as CKRecordValue?
        moveRec["plannedMoveDate"] = move.plannedMoveDate as CKRecordValue?
        moveRec["statusRaw"] = move.statusRaw as CKRecordValue
        moveRec["createdAt"] = move.createdAt as CKRecordValue
        moveRec["updatedAt"] = move.updatedAt as CKRecordValue
        out.append(moveRec)

        let moveRef = CKRecord.Reference(record: moveRec, action: .deleteSelf)

        // Rooms.
        for room in (move.rooms ?? []) {
            let r = CKRecord(recordType: RecordType.room,
                             recordID: CKRecord.ID(recordName: room.id, zoneID: zone))
            r["moveRef"] = moveRef
            r["kindRaw"] = room.kindRaw as CKRecordValue
            r["label"] = room.label as CKRecordValue
            r["sortOrder"] = room.sortOrder as CKRecordValue
            r["createdAt"] = room.createdAt as CKRecordValue
            r["updatedAt"] = room.updatedAt as CKRecordValue
            if let parent = room.parentRoom {
                r["parentRoomId"] = parent.id as CKRecordValue
            }
            out.append(r)
        }

        // BoxTypes.
        for bt in (move.boxTypes ?? []) {
            let r = CKRecord(recordType: RecordType.boxType,
                             recordID: CKRecord.ID(recordName: bt.id, zoneID: zone))
            r["moveRef"] = moveRef
            r["key"] = bt.key as CKRecordValue?
            r["label"] = bt.label as CKRecordValue
            r["volumeCuFt"] = bt.volumeCuFt as CKRecordValue?
            r["sortOrder"] = bt.sortOrder as CKRecordValue
            r["createdAt"] = bt.createdAt as CKRecordValue
            r["updatedAt"] = bt.updatedAt as CKRecordValue
            out.append(r)
        }

        // Items (with photo assets).
        for item in (move.items ?? []) {
            let r = CKRecord(recordType: RecordType.item,
                             recordID: CKRecord.ID(recordName: item.id, zoneID: zone))
            r["moveRef"] = moveRef
            r["name"] = item.name as CKRecordValue
            r["categoryId"] = item.categoryId as CKRecordValue?
            r["dispositionRaw"] = item.dispositionRaw as CKRecordValue
            r["fragilityRaw"] = item.fragilityRaw as CKRecordValue
            r["quantity"] = item.quantity as CKRecordValue
            r["estimatedValueUsd"] = item.estimatedValueUsd as CKRecordValue?
            r["volumeCuFtOverride"] = item.volumeCuFtOverride as CKRecordValue?
            r["weightLbsOverride"] = item.weightLbsOverride as CKRecordValue?
            r["notes"] = item.notes as CKRecordValue?
            r["sourceRoomId"] = item.sourceRoom?.id as CKRecordValue?
            r["destinationRoomId"] = item.destinationRoom?.id as CKRecordValue?
            r["createdAt"] = item.createdAt as CKRecordValue
            r["updatedAt"] = item.updatedAt as CKRecordValue
            out.append(r)

            let itemRef = CKRecord.Reference(record: r, action: .deleteSelf)
            for photo in (item.photos ?? []) {
                guard let data = photo.data else { continue }
                let photoRec = CKRecord(recordType: RecordType.itemPhoto,
                                        recordID: CKRecord.ID(recordName: photo.id, zoneID: zone))
                photoRec["itemRef"] = itemRef
                photoRec["width"] = photo.width as CKRecordValue?
                photoRec["height"] = photo.height as CKRecordValue?
                photoRec["byteSize"] = photo.byteSize as CKRecordValue?
                photoRec["contentType"] = photo.contentType as CKRecordValue?
                photoRec["createdAt"] = photo.createdAt as CKRecordValue
                if let assetURL = writeTempAsset(data: data, id: photo.id) {
                    photoRec["asset"] = CKAsset(fileURL: assetURL)
                }
                out.append(photoRec)
            }
        }

        // Boxes.
        for box in (move.boxes ?? []) {
            let r = CKRecord(recordType: RecordType.box,
                             recordID: CKRecord.ID(recordName: box.id, zoneID: zone))
            r["moveRef"] = moveRef
            r["shortCode"] = box.shortCode as CKRecordValue
            r["statusRaw"] = box.statusRaw as CKRecordValue
            r["tagsRaw"] = box.tagsRaw as CKRecordValue
            r["weightLbsActual"] = box.weightLbsActual as CKRecordValue?
            r["notes"] = box.notes as CKRecordValue?
            r["boxTypeId"] = box.boxType?.id as CKRecordValue?
            r["sourceRoomId"] = box.sourceRoom?.id as CKRecordValue?
            r["destinationRoomId"] = box.destinationRoom?.id as CKRecordValue?
            r["createdAt"] = box.createdAt as CKRecordValue
            r["updatedAt"] = box.updatedAt as CKRecordValue
            out.append(r)

            for bi in (box.boxItems ?? []) {
                let biRec = CKRecord(recordType: RecordType.boxItem,
                                     recordID: CKRecord.ID(recordName: bi.id, zoneID: zone))
                biRec["moveRef"] = moveRef
                biRec["boxId"] = box.id as CKRecordValue
                biRec["itemId"] = bi.item?.id as CKRecordValue?
                biRec["quantity"] = bi.quantity as CKRecordValue
                biRec["createdAt"] = bi.createdAt as CKRecordValue
                out.append(biRec)
            }
        }

        // Checklist.
        for chk in (move.checklist ?? []) {
            let r = CKRecord(recordType: RecordType.checklist,
                             recordID: CKRecord.ID(recordName: chk.id, zoneID: zone))
            r["moveRef"] = moveRef
            r["text"] = chk.text as CKRecordValue
            r["categoryRaw"] = chk.categoryRaw as CKRecordValue
            r["doneAt"] = chk.doneAt as CKRecordValue?
            r["sortOrder"] = chk.sortOrder as CKRecordValue
            r["createdAt"] = chk.createdAt as CKRecordValue
            r["updatedAt"] = chk.updatedAt as CKRecordValue
            out.append(r)
        }

        return out
    }

    // MARK: - CKRecords → SwiftData

    /// Given a set of records from a shared zone, materialize them into the
    /// local SwiftData store. Creates the Move + cascade if missing.
    ///
    /// Idempotent: re-running with the same records updates in place.
    /// Delta-safe: if the Move record itself isn't in the batch (e.g. only an
    /// Item changed), we still find-or-create the Move via the zone name.
    @MainActor
    static func materialize(
        records: [CKRecord],
        shareURL: URL?,
        ownerAppleUserId: String?,
        zoneName: String?,
        context: ModelContext
    ) {
        // Index by type.
        var byType: [String: [CKRecord]] = [:]
        for r in records { byType[r.recordType, default: []].append(r) }

        // Work out the moveId from either the Move record (if present) or
        // the zone name (for delta pushes that don't include the Move).
        let moveRec = byType[RecordType.move]?.first
        let inferredMoveId: String? = {
            if let mr = moveRec { return mr.recordID.recordName }
            if let zn = zoneName, zn.hasPrefix("move-") { return String(zn.dropFirst("move-".count)) }
            if let anyRec = records.first, anyRec.recordID.zoneID.zoneName.hasPrefix("move-") {
                return String(anyRec.recordID.zoneID.zoneName.dropFirst("move-".count))
            }
            return nil
        }()
        guard let moveId = inferredMoveId else { return }

        // Fetch-or-create Move. If the Move record is present, apply its
        // fields; otherwise leave the existing Move's fields unchanged (this
        // is a delta for children only).
        let move: Move
        let desc = FetchDescriptor<Move>(predicate: #Predicate { $0.id == moveId })
        if let existing = try? context.fetch(desc).first {
            move = existing
        } else {
            let initialName = moveRec?["name"] as? String ?? "Shared move"
            move = Move(id: moveId, name: initialName)
            context.insert(move)
        }
        if let mr = moveRec {
            move.name = mr["name"] as? String ?? move.name
            move.originAddress = mr["originAddress"] as? String
            move.destinationAddress = mr["destinationAddress"] as? String
            move.plannedMoveDate = mr["plannedMoveDate"] as? Date
            move.statusRaw = (mr["statusRaw"] as? String) ?? move.statusRaw
            move.updatedAt = (mr["updatedAt"] as? Date) ?? Date()
        }
        move.isShared = true
        if let shareURL { move.cloudKitShareURLString = shareURL.absoluteString }
        if let ownerAppleUserId { move.ownerAppleUserId = ownerAppleUserId }
        if let zoneName { move.cloudKitZoneName = zoneName }

        // Rooms first (items/boxes may reference them).
        var roomsById: [String: Room] = [:]
        for r in (byType[RecordType.room] ?? []) {
            let rid = r.recordID.recordName
            let fd = FetchDescriptor<Room>(predicate: #Predicate { $0.id == rid })
            let room = (try? context.fetch(fd).first) ?? {
                let new = Room(
                    id: rid, move: move,
                    kind: RoomKind(rawValue: (r["kindRaw"] as? String) ?? "origin") ?? .origin,
                    label: (r["label"] as? String) ?? ""
                )
                context.insert(new)
                return new
            }()
            room.move = move
            room.kindRaw = (r["kindRaw"] as? String) ?? room.kindRaw
            room.label = (r["label"] as? String) ?? room.label
            room.sortOrder = (r["sortOrder"] as? Int) ?? room.sortOrder
            room.updatedAt = (r["updatedAt"] as? Date) ?? Date()
            roomsById[rid] = room
        }

        // BoxTypes next (boxes reference them).
        var boxTypesById: [String: BoxType] = [:]
        for r in (byType[RecordType.boxType] ?? []) {
            let bid = r.recordID.recordName
            let fd = FetchDescriptor<BoxType>(predicate: #Predicate { $0.id == bid })
            let bt = (try? context.fetch(fd).first) ?? {
                let new = BoxType(id: bid, move: move, label: (r["label"] as? String) ?? "")
                context.insert(new)
                return new
            }()
            bt.move = move
            bt.key = r["key"] as? String
            bt.label = (r["label"] as? String) ?? bt.label
            bt.volumeCuFt = r["volumeCuFt"] as? Double
            bt.sortOrder = (r["sortOrder"] as? Int) ?? bt.sortOrder
            bt.updatedAt = (r["updatedAt"] as? Date) ?? Date()
            boxTypesById[bid] = bt
        }

        // Items.
        var itemsById: [String: Item] = [:]
        for r in (byType[RecordType.item] ?? []) {
            let iid = r.recordID.recordName
            let fd = FetchDescriptor<Item>(predicate: #Predicate { $0.id == iid })
            let item = (try? context.fetch(fd).first) ?? {
                let new = Item(id: iid, move: move, name: (r["name"] as? String) ?? "")
                context.insert(new)
                return new
            }()
            item.move = move
            item.name = (r["name"] as? String) ?? item.name
            item.categoryId = r["categoryId"] as? String
            item.dispositionRaw = (r["dispositionRaw"] as? String) ?? item.dispositionRaw
            item.fragilityRaw = (r["fragilityRaw"] as? String) ?? item.fragilityRaw
            item.quantity = (r["quantity"] as? Int) ?? item.quantity
            item.estimatedValueUsd = r["estimatedValueUsd"] as? Double
            item.volumeCuFtOverride = r["volumeCuFtOverride"] as? Double
            item.weightLbsOverride = r["weightLbsOverride"] as? Double
            item.notes = r["notes"] as? String
            if let srcId = r["sourceRoomId"] as? String {
                item.sourceRoom = roomsById[srcId] ?? fetchRoom(id: srcId, context: context)
            }
            if let dstId = r["destinationRoomId"] as? String {
                item.destinationRoom = roomsById[dstId] ?? fetchRoom(id: dstId, context: context)
            }
            item.updatedAt = (r["updatedAt"] as? Date) ?? Date()
            itemsById[iid] = item
        }

        // Item photos.
        for r in (byType[RecordType.itemPhoto] ?? []) {
            let pid = r.recordID.recordName
            let fd = FetchDescriptor<ItemPhoto>(predicate: #Predicate { $0.id == pid })
            let parentItemId: String? = {
                if let ref = r["itemRef"] as? CKRecord.Reference {
                    return ref.recordID.recordName
                }
                return nil
            }()
            let parentItem = parentItemId.flatMap { itemsById[$0] ?? fetchItem(id: $0, context: context) }
            let data: Data? = {
                guard let asset = r["asset"] as? CKAsset,
                      let url = asset.fileURL else { return nil }
                return try? Data(contentsOf: url)
            }()
            if let existing = try? context.fetch(fd).first {
                existing.item = parentItem
                existing.data = data ?? existing.data
                existing.width = r["width"] as? Int
                existing.height = r["height"] as? Int
                existing.byteSize = r["byteSize"] as? Int
                existing.contentType = r["contentType"] as? String
            } else {
                let new = ItemPhoto(
                    id: pid,
                    item: parentItem,
                    data: data,
                    width: r["width"] as? Int,
                    height: r["height"] as? Int,
                    byteSize: r["byteSize"] as? Int,
                    contentType: r["contentType"] as? String
                )
                context.insert(new)
            }
        }

        // Boxes.
        var boxesById: [String: Box] = [:]
        for r in (byType[RecordType.box] ?? []) {
            let bid = r.recordID.recordName
            let fd = FetchDescriptor<Box>(predicate: #Predicate { $0.id == bid })
            let boxTypeId = r["boxTypeId"] as? String
            let boxType = boxTypeId.flatMap { boxTypesById[$0] ?? fetchBoxType(id: $0, context: context) }
            let box = (try? context.fetch(fd).first) ?? {
                let new = Box(
                    id: bid, move: move,
                    shortCode: (r["shortCode"] as? String) ?? ShortCode.generateBoxShortCode(),
                    boxType: boxType
                )
                context.insert(new)
                return new
            }()
            box.move = move
            box.shortCode = (r["shortCode"] as? String) ?? box.shortCode
            box.statusRaw = (r["statusRaw"] as? String) ?? box.statusRaw
            box.tagsRaw = (r["tagsRaw"] as? [String]) ?? box.tagsRaw
            box.weightLbsActual = r["weightLbsActual"] as? Double
            box.notes = r["notes"] as? String
            box.boxType = boxType
            if let srcId = r["sourceRoomId"] as? String {
                box.sourceRoom = roomsById[srcId] ?? fetchRoom(id: srcId, context: context)
            }
            if let dstId = r["destinationRoomId"] as? String {
                box.destinationRoom = roomsById[dstId] ?? fetchRoom(id: dstId, context: context)
            }
            box.updatedAt = (r["updatedAt"] as? Date) ?? Date()
            boxesById[bid] = box
        }

        // BoxItems.
        for r in (byType[RecordType.boxItem] ?? []) {
            let biId = r.recordID.recordName
            let fd = FetchDescriptor<BoxItem>(predicate: #Predicate { $0.id == biId })
            let boxId = r["boxId"] as? String
            let itemId = r["itemId"] as? String
            let box = boxId.flatMap { boxesById[$0] ?? fetchBox(id: $0, context: context) }
            let item = itemId.flatMap { itemsById[$0] ?? fetchItem(id: $0, context: context) }
            if let existing = try? context.fetch(fd).first {
                existing.box = box
                existing.item = item
                existing.quantity = (r["quantity"] as? Int) ?? existing.quantity
            } else {
                let new = BoxItem(id: biId, box: box, item: item,
                                  quantity: (r["quantity"] as? Int) ?? 1)
                context.insert(new)
            }
        }

        // Checklist.
        for r in (byType[RecordType.checklist] ?? []) {
            let cid = r.recordID.recordName
            let fd = FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.id == cid })
            let category = ChecklistCategory(rawValue: (r["categoryRaw"] as? String) ?? "week") ?? .week
            let chk = (try? context.fetch(fd).first) ?? {
                let new = ChecklistItem(
                    id: cid, move: move,
                    text: (r["text"] as? String) ?? "",
                    category: category
                )
                context.insert(new)
                return new
            }()
            chk.move = move
            chk.text = (r["text"] as? String) ?? chk.text
            chk.categoryRaw = (r["categoryRaw"] as? String) ?? chk.categoryRaw
            chk.doneAt = r["doneAt"] as? Date
            chk.sortOrder = (r["sortOrder"] as? Int) ?? chk.sortOrder
            chk.updatedAt = (r["updatedAt"] as? Date) ?? Date()
        }

        try? context.save()
    }

    // MARK: - Single-entity builders (for delta push)

    /// Build a CKRecord for a single entity belonging to a shared Move.
    /// Returns nil if the entity has no known mapping.
    @MainActor
    static func singleRecord(for entity: Any, moveId: String) -> CKRecord? {
        let zone = zoneID(for: moveId)
        switch entity {
        case let m as Move:
            return moveRecord(m, in: zone)
        case let r as Room:
            return roomRecord(r, in: zone, moveId: moveId)
        case let i as Item:
            return itemRecord(i, in: zone, moveId: moveId)
        case let p as ItemPhoto:
            return itemPhotoRecord(p, in: zone)
        case let b as Box:
            return boxRecord(b, in: zone, moveId: moveId)
        case let bt as BoxType:
            return boxTypeRecord(bt, in: zone, moveId: moveId)
        case let bi as BoxItem:
            return boxItemRecord(bi, in: zone, moveId: moveId)
        case let c as ChecklistItem:
            return checklistRecord(c, in: zone, moveId: moveId)
        default:
            return nil
        }
    }

    @MainActor
    static func moveRecord(_ move: Move, in zone: CKRecordZone.ID) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.move,
            recordID: CKRecord.ID(recordName: move.id, zoneID: zone)
        )
        rec["name"] = move.name as CKRecordValue
        rec["originAddress"] = move.originAddress as CKRecordValue?
        rec["destinationAddress"] = move.destinationAddress as CKRecordValue?
        rec["plannedMoveDate"] = move.plannedMoveDate as CKRecordValue?
        rec["statusRaw"] = move.statusRaw as CKRecordValue
        rec["createdAt"] = move.createdAt as CKRecordValue
        rec["updatedAt"] = move.updatedAt as CKRecordValue
        return rec
    }

    @MainActor
    static func roomRecord(_ room: Room, in zone: CKRecordZone.ID, moveId: String) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.room,
            recordID: CKRecord.ID(recordName: room.id, zoneID: zone)
        )
        rec["moveRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: moveId, zoneID: zone),
            action: .deleteSelf
        )
        rec["kindRaw"] = room.kindRaw as CKRecordValue
        rec["label"] = room.label as CKRecordValue
        rec["sortOrder"] = room.sortOrder as CKRecordValue
        rec["createdAt"] = room.createdAt as CKRecordValue
        rec["updatedAt"] = room.updatedAt as CKRecordValue
        if let parent = room.parentRoom {
            rec["parentRoomId"] = parent.id as CKRecordValue
        }
        return rec
    }

    @MainActor
    static func itemRecord(_ item: Item, in zone: CKRecordZone.ID, moveId: String) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.item,
            recordID: CKRecord.ID(recordName: item.id, zoneID: zone)
        )
        rec["moveRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: moveId, zoneID: zone),
            action: .deleteSelf
        )
        rec["name"] = item.name as CKRecordValue
        rec["categoryId"] = item.categoryId as CKRecordValue?
        rec["dispositionRaw"] = item.dispositionRaw as CKRecordValue
        rec["fragilityRaw"] = item.fragilityRaw as CKRecordValue
        rec["quantity"] = item.quantity as CKRecordValue
        rec["estimatedValueUsd"] = item.estimatedValueUsd as CKRecordValue?
        rec["volumeCuFtOverride"] = item.volumeCuFtOverride as CKRecordValue?
        rec["weightLbsOverride"] = item.weightLbsOverride as CKRecordValue?
        rec["notes"] = item.notes as CKRecordValue?
        rec["sourceRoomId"] = item.sourceRoom?.id as CKRecordValue?
        rec["destinationRoomId"] = item.destinationRoom?.id as CKRecordValue?
        rec["createdAt"] = item.createdAt as CKRecordValue
        rec["updatedAt"] = item.updatedAt as CKRecordValue
        return rec
    }

    @MainActor
    static func itemPhotoRecord(_ photo: ItemPhoto, in zone: CKRecordZone.ID) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.itemPhoto,
            recordID: CKRecord.ID(recordName: photo.id, zoneID: zone)
        )
        if let parentItem = photo.item {
            rec["itemRef"] = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: parentItem.id, zoneID: zone),
                action: .deleteSelf
            )
        }
        rec["width"] = photo.width as CKRecordValue?
        rec["height"] = photo.height as CKRecordValue?
        rec["byteSize"] = photo.byteSize as CKRecordValue?
        rec["contentType"] = photo.contentType as CKRecordValue?
        rec["createdAt"] = photo.createdAt as CKRecordValue
        if let data = photo.data, let url = writeTempAsset(data: data, id: photo.id) {
            rec["asset"] = CKAsset(fileURL: url)
        }
        return rec
    }

    @MainActor
    static func boxRecord(_ box: Box, in zone: CKRecordZone.ID, moveId: String) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.box,
            recordID: CKRecord.ID(recordName: box.id, zoneID: zone)
        )
        rec["moveRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: moveId, zoneID: zone),
            action: .deleteSelf
        )
        rec["shortCode"] = box.shortCode as CKRecordValue
        rec["statusRaw"] = box.statusRaw as CKRecordValue
        rec["tagsRaw"] = box.tagsRaw as CKRecordValue
        rec["weightLbsActual"] = box.weightLbsActual as CKRecordValue?
        rec["notes"] = box.notes as CKRecordValue?
        rec["boxTypeId"] = box.boxType?.id as CKRecordValue?
        rec["sourceRoomId"] = box.sourceRoom?.id as CKRecordValue?
        rec["destinationRoomId"] = box.destinationRoom?.id as CKRecordValue?
        rec["createdAt"] = box.createdAt as CKRecordValue
        rec["updatedAt"] = box.updatedAt as CKRecordValue
        return rec
    }

    @MainActor
    static func boxTypeRecord(_ bt: BoxType, in zone: CKRecordZone.ID, moveId: String) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.boxType,
            recordID: CKRecord.ID(recordName: bt.id, zoneID: zone)
        )
        rec["moveRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: moveId, zoneID: zone),
            action: .deleteSelf
        )
        rec["key"] = bt.key as CKRecordValue?
        rec["label"] = bt.label as CKRecordValue
        rec["volumeCuFt"] = bt.volumeCuFt as CKRecordValue?
        rec["sortOrder"] = bt.sortOrder as CKRecordValue
        rec["createdAt"] = bt.createdAt as CKRecordValue
        rec["updatedAt"] = bt.updatedAt as CKRecordValue
        return rec
    }

    @MainActor
    static func boxItemRecord(_ bi: BoxItem, in zone: CKRecordZone.ID, moveId: String) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.boxItem,
            recordID: CKRecord.ID(recordName: bi.id, zoneID: zone)
        )
        rec["moveRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: moveId, zoneID: zone),
            action: .deleteSelf
        )
        rec["boxId"] = bi.box?.id as CKRecordValue?
        rec["itemId"] = bi.item?.id as CKRecordValue?
        rec["quantity"] = bi.quantity as CKRecordValue
        rec["createdAt"] = bi.createdAt as CKRecordValue
        return rec
    }

    @MainActor
    static func checklistRecord(_ chk: ChecklistItem, in zone: CKRecordZone.ID, moveId: String) -> CKRecord {
        let rec = CKRecord(
            recordType: RecordType.checklist,
            recordID: CKRecord.ID(recordName: chk.id, zoneID: zone)
        )
        rec["moveRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: moveId, zoneID: zone),
            action: .deleteSelf
        )
        rec["text"] = chk.text as CKRecordValue
        rec["categoryRaw"] = chk.categoryRaw as CKRecordValue
        rec["doneAt"] = chk.doneAt as CKRecordValue?
        rec["sortOrder"] = chk.sortOrder as CKRecordValue
        rec["createdAt"] = chk.createdAt as CKRecordValue
        rec["updatedAt"] = chk.updatedAt as CKRecordValue
        return rec
    }

    // MARK: - Local lookup fallbacks (used for cross-batch references)

    @MainActor
    private static func fetchRoom(id: String, context: ModelContext) -> Room? {
        try? context.fetch(FetchDescriptor<Room>(predicate: #Predicate { $0.id == id })).first
    }

    @MainActor
    private static func fetchItem(id: String, context: ModelContext) -> Item? {
        try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })).first
    }

    @MainActor
    private static func fetchBox(id: String, context: ModelContext) -> Box? {
        try? context.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.id == id })).first
    }

    @MainActor
    private static func fetchBoxType(id: String, context: ModelContext) -> BoxType? {
        try? context.fetch(FetchDescriptor<BoxType>(predicate: #Predicate { $0.id == id })).first
    }

    // MARK: - Deletions

    /// Walk every app model type, find any entity whose `id` matches one of
    /// the deleted CKRecord.IDs, and delete it locally. Idempotent — safe to
    /// call even if the entity is already gone.
    @MainActor
    static func applyDeletions(recordIDs: [CKRecord.ID], context: ModelContext) {
        let deletedNames = Set(recordIDs.map { $0.recordName })
        guard !deletedNames.isEmpty else { return }

        deleteMatching(Move.self, ids: deletedNames, context: context)
        deleteMatching(Room.self, ids: deletedNames, context: context)
        deleteMatching(Item.self, ids: deletedNames, context: context)
        deleteMatching(ItemPhoto.self, ids: deletedNames, context: context)
        deleteMatching(Box.self, ids: deletedNames, context: context)
        deleteMatching(BoxType.self, ids: deletedNames, context: context)
        deleteMatching(BoxItem.self, ids: deletedNames, context: context)
        deleteMatching(ChecklistItem.self, ids: deletedNames, context: context)

        try? context.save()
    }

    @MainActor
    private static func deleteMatching<T: PersistentModel>(
        _ type: T.Type,
        ids: Set<String>,
        context: ModelContext
    ) {
        guard let results = try? context.fetch(FetchDescriptor<T>()) else { return }
        for model in results {
            // Every Pakt model has an `id: String` field; read it via Mirror
            // to avoid needing a shared protocol across the @Model types.
            if let idValue = Mirror(reflecting: model).children.first(where: { $0.label == "id" })?.value as? String,
               ids.contains(idValue) {
                context.delete(model)
            }
        }
    }

    // MARK: - Helpers

    private static func writeTempAsset(data: Data, id: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pakt-asset-\(id)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
