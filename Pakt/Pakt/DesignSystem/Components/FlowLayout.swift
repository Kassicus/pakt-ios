import SwiftUI

/// Wrapping horizontal layout — children flow left-to-right, breaking to new lines when they
/// overflow available width. Used for chip groups (tags, category selectors, filter pills).
public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let layout = resolve(subviews: subviews, maxWidth: maxWidth)
        return CGSize(width: layout.width, height: layout.height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = resolve(subviews: subviews, maxWidth: bounds.width)
        for placement in layout.placements {
            let origin = CGPoint(
                x: bounds.minX + placement.origin.x,
                y: bounds.minY + placement.origin.y
            )
            subviews[placement.index].place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private struct LayoutResult {
        var width: CGFloat
        var height: CGFloat
        var placements: [Placement]
    }

    private struct Placement {
        var index: Int
        var origin: CGPoint
        var size: CGSize
    }

    private func resolve(subviews: Subviews, maxWidth: CGFloat) -> LayoutResult {
        var placements: [Placement] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX + size.width > maxWidth, cursorX > 0 {
                cursorX = 0
                cursorY += lineHeight + lineSpacing
                lineHeight = 0
            }
            placements.append(Placement(index: index, origin: CGPoint(x: cursorX, y: cursorY), size: size))
            cursorX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            contentWidth = max(contentWidth, cursorX - spacing)
        }

        return LayoutResult(width: contentWidth, height: cursorY + lineHeight, placements: placements)
    }
}
