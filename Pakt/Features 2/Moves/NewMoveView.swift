import PaktCore
import SwiftData
import SwiftUI

struct NewMoveView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var originAddress = ""
    @State private var destinationAddress = ""
    @State private var hasDate = false
    @State private var plannedMoveDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paktBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: PaktSpace.s4) {
                        field(label: "Name", required: true) {
                            PaktTextField("Our move to the new house", text: $name)
                        }
                        field(label: "Origin address") {
                            PaktTextField("Optional", text: $originAddress)
                        }
                        field(label: "Destination address") {
                            PaktTextField("Optional", text: $destinationAddress)
                        }

                        VStack(alignment: .leading, spacing: PaktSpace.s2) {
                            Toggle(isOn: $hasDate) {
                                Text("Planned move date").font(.pakt(.bodyMedium))
                                    .foregroundStyle(Color.paktForeground)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.paktPrimary))

                            if hasDate {
                                DatePicker("", selection: $plannedMoveDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .tint(Color.paktPrimary)
                            }
                        }

                        Spacer(minLength: PaktSpace.s6)

                        PaktButton("Create move", size: .lg, action: submit)
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.6)

                        Text("We'll seed default rooms, box types, and a move checklist.")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktMutedForeground)
                    }
                    .padding(PaktSpace.s4)
                }
            }
            .navigationTitle("New move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.paktMutedForeground)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let move = Move(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            originAddress: originAddress.isEmpty ? nil : originAddress,
            destinationAddress: destinationAddress.isEmpty ? nil : destinationAddress,
            plannedMoveDate: hasDate ? plannedMoveDate : nil
        )
        context.insert(move)
        MoveSeeder.seedDefaults(for: move, context: context)
        try? context.save()
        dismiss()
    }

    @ViewBuilder
    private func field<Content: View>(
        label: String, required: Bool = false,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PaktSpace.s1) {
            HStack(spacing: 4) {
                Text(label).font(.pakt(.small)).foregroundStyle(Color.paktMutedForeground)
                if required {
                    Text("·").foregroundStyle(Color.paktMutedForeground)
                    Text("required").font(.pakt(.small)).foregroundStyle(Color.paktMutedForeground)
                }
            }
            content()
        }
    }
}
