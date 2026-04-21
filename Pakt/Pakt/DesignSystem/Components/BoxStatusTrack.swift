import SwiftUI

public struct BoxStatusTrack: View {
    private let current: BoxStatus
    private let ordered = BoxStatus.ordered

    public init(current: BoxStatus) {
        self.current = current
    }

    public var body: some View {
        let idx = ordered.firstIndex(of: current) ?? 0
        GeometryReader { geo in
            let span = max(ordered.count - 1, 1)
            let step = geo.size.width / CGFloat(span)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.paktBorder)
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
                Capsule()
                    .fill(Color.paktPrimary)
                    .frame(width: step * CGFloat(idx), height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .animation(PaktMotion.sheet, value: current)
                HStack(spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.offset) { i, _ in
                        dot(isFilled: i <= idx, isCurrent: i == idx)
                            .frame(maxWidth: .infinity)
                            .animation(PaktMotion.sheet, value: current)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(current.label). Step \(idx + 1) of \(ordered.count).")
    }

    @ViewBuilder
    private func dot(isFilled: Bool, isCurrent: Bool) -> some View {
        let size: CGFloat = isCurrent ? 14 : 10
        Circle()
            .fill(isFilled ? Color.paktPrimary : Color.paktCard)
            .overlay(Circle().strokeBorder(Color.paktBorder, lineWidth: 1))
            .frame(width: size, height: size)
            .shadow(color: isCurrent ? Color.paktPrimary.opacity(0.35) : .clear, radius: 6)
    }
}

#Preview("Status track") {
    VStack(spacing: PaktSpace.s5) {
        ForEach(BoxStatus.ordered, id: \.self) { status in
            VStack(alignment: .leading, spacing: 6) {
                Text(status.label).font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                BoxStatusTrack(current: status)
            }
        }
    }
    .padding(PaktSpace.s4)
    .background(Color.paktBackground)
}
