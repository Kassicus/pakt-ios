import Foundation
import SwiftData

/// Populates a freshly-created Move with the same defaults the web app seeds:
/// rooms per side, per-move box types, and the pre-move checklist.
enum MoveSeeder {
    @MainActor
    static func seedDefaults(for move: Move, context: ModelContext) {
        seedRooms(for: move, context: context)
        seedBoxTypes(for: move, context: context)
        seedChecklist(for: move, context: context)
    }

    @MainActor
    private static func seedRooms(for move: Move, context: ModelContext) {
        var order = 0
        for entry in DefaultRooms.all {
            for kind in entry.sides {
                context.insert(Room(move: move, kind: kind, label: entry.label, sortOrder: order))
                order += 10
            }
        }
    }

    @MainActor
    private static func seedBoxTypes(for move: Move, context: ModelContext) {
        for t in DefaultBoxTypes.all {
            let volume = NSDecimalNumber(decimal: t.volumeCuFt).doubleValue
            context.insert(
                BoxType(move: move, key: t.key, label: t.label,
                        volumeCuFt: volume, sortOrder: t.sortOrder)
            )
        }
    }

    @MainActor
    private static func seedChecklist(for move: Move, context: ModelContext) {
        struct Entry { let text: String; let category: ChecklistCategory }
        let entries: [Entry] = [
            .init(text: "Book movers or reserve a truck",        category: .d30),
            .init(text: "Notify landlord or list your home",     category: .d30),
            .init(text: "Sort and start donating early",         category: .d30),
            .init(text: "Order boxes and packing supplies",      category: .w2),
            .init(text: "Change your address with USPS",         category: .w2),
            .init(text: "Transfer utilities at the new place",   category: .w2),
            .init(text: "Pack everything you won't need",        category: .week),
            .init(text: "Confirm moving day plans",              category: .week),
            .init(text: "Pack a first-night box",                category: .day),
            .init(text: "Label every box",                       category: .day),
            .init(text: "Unpack kitchen + beds first",           category: .after),
            .init(text: "Return modems / cable boxes",           category: .after),
        ]
        for (index, entry) in entries.enumerated() {
            context.insert(
                ChecklistItem(move: move, text: entry.text, category: entry.category,
                              sortOrder: index * 10)
            )
        }
    }
}
