import SwiftUI

/// Horizontal label/value row for use inside `PaktSurface`. Fields auto-separate with hairline
/// dividers when stacked, so you can drop a sequence of them and get a form-like feel without
/// using `Form`.
public struct PaktField<Value: View>: View {
    private let label: String
    private let value: Value

    public init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: PaktSpace.s3) {
            Text(label)
                .font(.pakt(.bodyMedium))
                .foregroundStyle(Color.paktForeground)
            Spacer(minLength: PaktSpace.s2)
            value
                .font(.pakt(.body))
                .foregroundStyle(Color.paktMutedForeground)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 32)
    }
}

/// Draws a thin divider between adjacent children. Use inside `PaktSurface` instead of a plain
/// `VStack` when you want form-like separators.
public struct PaktFieldStack<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        _VariadicView.Tree(FieldStackLayout()) {
            content
        }
    }

    private struct FieldStackLayout: _VariadicView_MultiViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.offset) { idx, child in
                    if idx > 0 {
                        Rectangle()
                            .fill(Color.paktBorder.opacity(0.6))
                            .frame(height: 1)
                            .padding(.vertical, 4)
                    }
                    child
                }
            }
        }
    }
}
