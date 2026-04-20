import SwiftData
import SwiftUI
import UIKit

/// Four disposition "zones" — drag direction commits a card to one of these.
/// Order matches the web app's triage chips: Moving (right), Storage (up),
/// Donate (down), Trash (left).
private enum TriageZone: CaseIterable {
    case moving, storage, donate, trash

    var disposition: Disposition {
        switch self {
        case .moving:  return .moving
        case .storage: return .storage
        case .donate:  return .donate
        case .trash:   return .trash
        }
    }

    var label: String {
        switch self {
        case .moving:  return "Moving"
        case .storage: return "Storage"
        case .donate:  return "Donate"
        case .trash:   return "Trash"
        }
    }

    var tone: PaktBadgeTone {
        switch self {
        case .moving:  return .default
        case .storage: return .secondary
        case .donate:  return .outline
        case .trash:   return .destructive
        }
    }

    var icon: String {
        switch self {
        case .moving:  return "truck"
        case .storage: return "box"
        case .donate:  return "share"
        case .trash:   return "trash"
        }
    }
}

struct TriageDeckView: View {
    let move: Move

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dragTranslation: CGSize = .zero
    @State private var committingZone: TriageZone?
    @State private var undoState: UndoState?
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let successHaptic = UINotificationFeedbackGenerator()

    private let commitThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            if visibleItems.isEmpty {
                EmptyTriageView { dismiss() }
            } else {
                VStack(spacing: PaktSpace.s4) {
                    ProgressBar(completed: completedCount, total: totalCount)
                        .padding(.horizontal, PaktSpace.s4)
                        .padding(.top, PaktSpace.s2)

                    cardStack
                        .padding(.horizontal, PaktSpace.s4)

                    dispositionPad
                        .padding(.horizontal, PaktSpace.s4)
                        .padding(.bottom, PaktSpace.s4)
                }
            }

            if let toast = undoState {
                VStack {
                    Spacer()
                    UndoToast(message: toast.message) { undo(toast) }
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Triage")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Card stack

    private var cardStack: some View {
        ZStack {
            ForEach(Array(visibleItems.prefix(3).enumerated().reversed()), id: \.element.id) { index, item in
                cardView(index: index, item: item)
            }
        }
    }

    @ViewBuilder
    private func cardView(index: Int, item: Item) -> some View {
        let depth = CGFloat(index)
        let offset = index == 0 ? dragTranslation : CGSize(width: 0, height: -depth * CGFloat(8))
        let rotation = index == 0 ? Angle.degrees(Double(dragTranslation.width) / 18) : .zero
        let scale: CGFloat = 1 - depth * CGFloat(0.04)
        let op: Double = 1 - Double(depth) * 0.15
        let z: Double = Double(10 - Int(depth))

        let base = TriageCardView(item: item)
            .offset(offset)
            .rotationEffect(rotation)
            .scaleEffect(scale)
            .opacity(op)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.8), value: dragTranslation)
            .overlay(alignment: .top) {
                cardOverlay(index: index)
            }
            .zIndex(z)

        if index == 0 {
            base.gesture(dragGesture(for: item))
        } else {
            base
        }
    }

    @ViewBuilder
    private func cardOverlay(index: Int) -> some View {
        if index == 0, let zone = currentZone {
            ZoneBadge(zone: zone)
                .padding(.top, PaktSpace.s2)
                .transition(.opacity)
        }
    }

    private func dragGesture(for item: Item) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                guard let zone = zoneForCommit(translation: value.translation) else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragTranslation = .zero
                    }
                    return
                }
                commit(item: item, to: zone, direction: value.translation)
            }
    }

    private func zoneForCommit(translation: CGSize) -> TriageZone? {
        let dx = translation.width
        let dy = translation.height
        if abs(dx) < commitThreshold && abs(dy) < commitThreshold { return nil }
        if abs(dx) > abs(dy) { return dx > 0 ? .moving : .trash }
        return dy < 0 ? .storage : .donate
    }

    private var currentZone: TriageZone? {
        zoneForCommit(translation: dragTranslation)
    }

    // MARK: - Commit + undo

    private func commit(item: Item, to zone: TriageZone, direction: CGSize) {
        haptic.impactOccurred()
        let previous = item.disposition
        let flingX = direction.width == 0 ? (zone == .moving ? 1 : -1) : (direction.width > 0 ? 1 : -1)
        let flingY = direction.height == 0 ? 0.0 : direction.height / max(abs(direction.height), 1)

        withAnimation(.easeOut(duration: 0.24)) {
            dragTranslation = CGSize(
                width: CGFloat(flingX) * 700,
                height: CGFloat(flingY) * 500
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            item.disposition = zone.disposition
            item.updatedAt = Date()
            try? context.save()
            undoState = UndoState(itemId: item.id,
                                  previous: previous,
                                  message: "\(item.name) → \(zone.label)")
            successHaptic.notificationOccurred(.success)
            dragTranslation = .zero
        }
    }

    private func undo(_ state: UndoState) {
        if let item = visibleOrAllItems.first(where: { $0.id == state.itemId }) {
            item.disposition = state.previous
            item.updatedAt = Date()
            try? context.save()
        }
        undoState = nil
    }

    // MARK: - Disposition pad (tap-to-commit fallback)

    private var dispositionPad: some View {
        HStack(spacing: PaktSpace.s2) {
            ForEach(TriageZone.allCases, id: \.self) { zone in
                Button {
                    guard let first = visibleItems.first else { return }
                    commit(item: first, to: zone, direction: direction(for: zone))
                } label: {
                    VStack(spacing: 4) {
                        Image(paktIcon: zone.icon)
                            .font(.system(size: 18, weight: .medium))
                        Text(zone.label).font(.pakt(.small))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(Color.paktForeground)
                    .background(RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                        .fill(Color.paktCard))
                    .overlay(RoundedRectangle(cornerRadius: PaktRadius.lg)
                        .strokeBorder(tintColor(for: zone).opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(visibleItems.isEmpty)
            }
        }
    }

    private func direction(for zone: TriageZone) -> CGSize {
        switch zone {
        case .moving:  return CGSize(width:  300, height: 0)
        case .trash:   return CGSize(width: -300, height: 0)
        case .storage: return CGSize(width: 0, height: -300)
        case .donate:  return CGSize(width: 0, height:  300)
        }
    }

    private func tintColor(for zone: TriageZone) -> Color {
        switch zone {
        case .moving:  return Color.paktMoving
        case .storage: return Color.paktStorage
        case .donate:  return Color.paktDonate
        case .trash:   return Color.paktDestructive
        }
    }

    // MARK: - Data

    private var visibleItems: [Item] {
        (move.items ?? [])
            .filter { $0.disposition == .undecided && $0.deletedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var visibleOrAllItems: [Item] {
        (move.items ?? []).filter { $0.deletedAt == nil }
    }

    private var totalCount: Int {
        (move.items ?? []).filter { $0.deletedAt == nil }.count
    }

    private var completedCount: Int {
        totalCount - visibleItems.count
    }

    // MARK: - Types

    private struct UndoState: Equatable {
        let itemId: String
        let previous: Disposition
        let message: String
    }
}

// MARK: - Subviews

private struct ZoneBadge: View {
    let zone: TriageZone
    var body: some View {
        PaktBadge(zone.label, tone: zone.tone)
            .font(.pakt(.bodyMedium))
            .scaleEffect(1.3)
    }
}

private struct ProgressBar: View {
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(completed) of \(total) triaged")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.paktMuted).frame(height: 4)
                    Capsule().fill(Color.paktPrimary)
                        .frame(width: geo.size.width * fraction, height: 4)
                        .animation(.easeOut(duration: 0.25), value: completed)
                }
            }
            .frame(height: 4)
        }
    }

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(completed) / CGFloat(total)
    }
}

private struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            Text(message)
                .font(.pakt(.body))
                .foregroundStyle(Color.paktForeground)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Undo", action: onUndo)
                .font(.pakt(.bodyMedium))
                .foregroundStyle(Color.paktPrimary)
        }
        .padding(.horizontal, PaktSpace.s3)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: PaktRadius.lg)
                .fill(Color.paktCard)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.lg)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
        .padding(.horizontal, PaktSpace.s4)
    }
}

private struct EmptyTriageView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: PaktSpace.s3) {
            Image(paktIcon: "check-circle")
                .font(.system(size: 44))
                .foregroundStyle(Color.paktMoving)
            Text("All caught up").font(.pakt(.heading))
            Text("Every item has a disposition. Come back after you add more.")
                .multilineTextAlignment(.center)
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .padding(.horizontal, PaktSpace.s6)
            PaktButton("Back to dashboard", action: onDone)
                .padding(.top, PaktSpace.s2)
        }
    }
}
