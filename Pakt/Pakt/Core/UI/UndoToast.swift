import SwiftUI

/// Lightweight top-of-screen toast surfaced after a soft-delete, so the
/// deletion is visible and reversible. Attach once at the app root via
/// `.undoToastHost()` and fire with `UndoToastCenter.shared.show(...)`.
@MainActor
@Observable
final class UndoToastCenter {
    static let shared = UndoToastCenter()

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let undo: (@MainActor () -> Void)?

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    private(set) var current: Toast?

    private var dismissTask: Task<Void, Never>?

    private init() {}

    /// Display a toast. `undo` is optional — when nil the toast still appears
    /// but without an Undo button (useful for acknowledgement-only messages).
    func show(message: String, undo: (@MainActor () -> Void)? = nil, duration: TimeInterval = 4) {
        dismissTask?.cancel()
        current = Toast(message: message, undo: undo)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.current = nil }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }

    func performUndo() {
        guard let undo = current?.undo else { dismiss(); return }
        undo()
        dismiss()
    }
}

private struct UndoToastHost: ViewModifier {
    @Bindable var center: UndoToastCenter = .shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                UndoToastView(toast: toast)
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.top, PaktSpace.s2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: center.current)
    }
}

private struct UndoToastView: View {
    let toast: UndoToastCenter.Toast

    var body: some View {
        HStack(spacing: PaktSpace.s3) {
            Text(toast.message)
                .font(.pakt(.body))
                .foregroundStyle(Color.paktForeground)
                .lineLimit(2)
            Spacer(minLength: PaktSpace.s2)
            if toast.undo != nil {
                Button("Undo") { UndoToastCenter.shared.performUndo() }
                    .font(.pakt(.bodyMedium))
                    .foregroundStyle(Color.paktPrimary)
            }
            Button {
                UndoToastCenter.shared.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.paktMutedForeground)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, PaktSpace.s4)
        .padding(.vertical, PaktSpace.s3)
        .background(
            RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                .fill(Color.paktCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                .strokeBorder(Color.paktBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }
}

extension View {
    /// Installs the undo toast overlay. Apply once at the app root.
    func undoToastHost() -> some View {
        modifier(UndoToastHost())
    }
}
