import SwiftUI

public struct PaktTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let isSecure: Bool

    @FocusState private var focused: Bool

    public init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
    }

    public var body: some View {
        field
            .font(.pakt(.body))
            .foregroundStyle(Color.paktForeground)
            .focused($focused)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                    .strokeBorder(focused ? Color.paktRing : Color.paktBorder,
                                  lineWidth: focused ? 2 : 1)
            )
            .animation(PaktMotion.quick, value: focused)
    }

    @ViewBuilder private var field: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }
}
