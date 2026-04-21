import SwiftUI
import TipKit

/// TipKit tips that teach swipe-to-delete on each list surface the first time
/// the user sees it with data. Each tip dismisses itself on first use via
/// `invalidate(reason: .actionPerformed)` so it never appears again.
///
/// Configure the datastore once in `PaktApp.init()` via `Tips.configure(...)`.

enum DeletionTipEvents {
    /// Call once, from any swipe handler, after the user has performed a real
    /// deletion. Invalidates every deletion-teaching tip so they don't appear
    /// again on adjacent lists — once the user discovers the pattern, they
    /// understand it globally.
    @MainActor
    static func userDidSwipeToDelete() {
        SwipeToDeleteBoxTip().invalidate(reason: .actionPerformed)
        SwipeToDeleteItemTip().invalidate(reason: .actionPerformed)
        SwipeToDeleteBoxTypeTip().invalidate(reason: .actionPerformed)
        SwipeToDeleteMoveTip().invalidate(reason: .actionPerformed)
        SwipeToDeleteRoomTip().invalidate(reason: .actionPerformed)
        SwipeToRemoveBoxItemTip().invalidate(reason: .actionPerformed)
    }
}

struct SwipeToDeleteBoxTip: Tip {
    var title: Text { Text("Remove a box") }
    var message: Text? { Text("Swipe left on any box to remove it. Tap Undo in the toast if you change your mind.") }
    var image: Image? { Image(systemName: "trash") }
}

struct SwipeToDeleteItemTip: Tip {
    var title: Text { Text("Remove an item") }
    var message: Text? { Text("Swipe left on any item to remove it. You can undo right after.") }
    var image: Image? { Image(systemName: "trash") }
}

struct SwipeToDeleteBoxTypeTip: Tip {
    var title: Text { Text("Manage box types") }
    var message: Text? { Text("Swipe left to remove a type you no longer need. Types in use can't be removed until their boxes move elsewhere.") }
    var image: Image? { Image(systemName: "trash") }
}

struct SwipeToDeleteMoveTip: Tip {
    var title: Text { Text("Remove a move") }
    var message: Text? { Text("Swipe left on any move to remove it. You'll be asked to confirm first.") }
    var image: Image? { Image(systemName: "trash") }
}

struct SwipeToDeleteRoomTip: Tip {
    var title: Text { Text("Remove a room") }
    var message: Text? { Text("Swipe left on any room to remove it. Sub-rooms become top-level.") }
    var image: Image? { Image(systemName: "trash") }
}

struct SwipeToRemoveBoxItemTip: Tip {
    var title: Text { Text("Remove from this box") }
    var message: Text? { Text("Swipe left on a row to take it out of the box. The item itself stays in your inventory.") }
    var image: Image? { Image(systemName: "arrow.uturn.backward") }
}
