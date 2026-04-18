import SwiftUI

/// Pill-style segmented picker matching the web's `Tabs` primitive.
public struct PaktTabs<Value: Hashable>: View {
    public struct Option: Identifiable {
        public let value: Value
        public let label: String
        public var id: Value { value }

        public init(value: Value, label: String) {
            self.value = value
            self.label = label
        }
    }

    @Binding private var selection: Value
    private let options: [Option]

    public init(selection: Binding<Value>, options: [Option]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(PaktMotion.quick) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.pakt(.bodyMedium))
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .foregroundStyle(isSelected ? Color.paktForeground : Color.paktMutedForeground)
                        .background(
                            RoundedRectangle(cornerRadius: PaktRadius.md, style: .continuous)
                                .fill(isSelected ? Color.paktCard : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: PaktRadius.lg, style: .continuous)
                .fill(Color.paktMuted)
        )
    }
}
