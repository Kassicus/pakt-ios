import SwiftUI

public struct PaktCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    public init(padding: CGFloat = PaktSpace.s4, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                    .fill(Color.paktCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PaktRadius.xl, style: .continuous)
                    .strokeBorder(Color.paktBorder, lineWidth: 1)
            )
    }
}
