# Deletion pattern

One consistent pattern for every deletable entity in the app. When you add a new entity or a new list surface, follow this checklist.

## The rule

**Every deletable entity gets two affordances:**

1. **Swipe-to-delete** on the list row (primary, muscle-memory path).
2. **Destructive "Remove *{entity}*" button** at the bottom of its detail or edit sheet (discoverable, always-visible path).

No context menus. No overlay × buttons. No hidden gestures.

## Soft-delete vs. hard-delete

| Entity type | Deletion | Rationale |
|---|---|---|
| User-owned content (Move, Room, Item, Box, BoxType, ItemPhoto) | **Soft-delete** (set `deletedAt`) | Recoverable via undo toast; tombstone syncs to other devices. |
| Junction / link rows (BoxItem) | **Hard-delete** | No user-facing identity; removing is the whole point. |
| Revokable grants (share participants) | **Revoke** | Not a delete — managed by CloudKit share API. |

**Every `@Model` that can be user-deleted must have `public var deletedAt: Date?`.**

## Confirmation dialogs

- **Soft-deletes:** silent. The undo toast is the user feedback.
- **Hard-deletes:** always show a `confirmationDialog` explaining the consequence.
- **Edge case:** soft-deletes that have cascade effects visible to the user (e.g. removing a Move hides all its rooms/items/boxes) get a confirmation *and* an undo toast, because the blast radius is larger than the row.

## Undo toast

- Every soft-delete call site fires `UndoToastCenter.shared.show(message:undo:)`.
- Message format: `"\(entity name) removed"` — e.g. `"Box K7-2X removed"`, `"Kitchen removed"`, `"\"Medium\" removed"`. Use quotes around free-text labels, bare text for ID-like strings.
- `undo:` closure must restore `deletedAt = nil` and save. Auto-dismisses after 4 seconds.

## TipKit

- Every list that supports swipe-to-delete has a `TipView(SwipeToDelete*Tip())` row at the top of its `List`.
- Tips configured once in `PaktApp.init()` via `Tips.configure(...)`.
- Tips invalidate globally on first swipe via `DeletionTipEvents.userDidSwipeToDelete()` — once the user learns the pattern on any list, tips disappear everywhere.
- Users can reset tips from **Settings → Data → Reset tips**.

## Filtering

Whenever you read a relationship or fetch a soft-deletable model:

```swift
// ✅ Correct
let rooms = (move.rooms ?? []).filter { $0.deletedAt == nil }
let moves = @Query(filter: #Predicate<Move> { $0.deletedAt == nil })

// ❌ Wrong — exposes tombstoned rows in the UI
let rooms = move.rooms ?? []
```

**Sync-layer code (`MoveCKRecordMapper`, `CloudKitSyncEngine`) intentionally includes tombstones** so they propagate across devices. Never filter there.

## Purge

`TrashSweeper.sweep(context:)` runs on app launch and hard-deletes tombstoned rows older than `TrashSweeper.retention` (7 days). **Currently gated behind `TrashSweeper.isEnabled = false`** until CloudKit tombstone propagation has been verified in the wild. Flip the flag once verified.

## Labels & visuals

- Destructive buttons: `Label("Remove \(entity)", systemImage: "trash")`, `role: .destructive`.
- Dialog title: `"Remove this \(entity)?"`, destructive button label `"Remove"`, cancel `"Cancel"`.
- Never use "Delete permanently" — our deletes are reversible.

## Checklist for new entities

When adding a new `@Model`:

- [ ] Does it need user-triggered deletion? If yes, add `deletedAt: Date?`.
- [ ] Add to `MoveCKRecordMapper` serialize + deserialize (serializer *includes* `deletedAt`).
- [ ] Add to `TrashSweeper.sweep` purge list.
- [ ] Add filters (`filter { $0.deletedAt == nil }`) to every read site in UI.
- [ ] List view: add `.onDelete { ... }` handler that soft-deletes + fires toast + calls `DeletionTipEvents.userDidSwipeToDelete()`.
- [ ] Add `TipView(SwipeToDelete*Tip())` as first row.
- [ ] Detail/edit sheet: add `Section { Button(role: .destructive) { ... } label: { Label("Remove \(entity)", systemImage: "trash") } }`.
- [ ] Create a `SwipeToDelete*Tip: Tip` in `DeletionTips.swift` and register it in `DeletionTipEvents.userDidSwipeToDelete()`.
