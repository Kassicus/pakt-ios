import SwiftData
import SwiftUI

struct DecisionQuizView: View {
    @Bindable var item: Item

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var lastUsedMonthsRaw: Double = 6
    @State private var replacementCostRaw: Double = 100
    @State private var sentimental: Bool? = nil
    @State private var wouldBuy: WouldBuyAgain? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("How long since you last used it?") {
                    VStack(alignment: .leading, spacing: PaktSpace.s2) {
                        Text(lastUsedLabel).font(.pakt(.body))
                        Slider(value: $lastUsedMonthsRaw, in: 0...48, step: 1)
                    }
                }

                Section("How much to replace?") {
                    VStack(alignment: .leading, spacing: PaktSpace.s2) {
                        Text(replacementCostLabel).font(.pakt(.body))
                        Slider(value: $replacementCostRaw, in: 0...1000, step: 5)
                    }
                }

                Section("Sentimental value?") {
                    Picker("", selection: $sentimental) {
                        Text("Skip").tag(Bool?.none)
                        Text("No").tag(Bool?.some(false))
                        Text("Yes").tag(Bool?.some(true))
                    }
                    .pickerStyle(.segmented)
                }

                Section("Would you buy it again?") {
                    Picker("", selection: $wouldBuy) {
                        Text("Skip").tag(WouldBuyAgain?.none)
                        Text("Yes").tag(WouldBuyAgain?.some(.yes))
                        Text("Unsure").tag(WouldBuyAgain?.some(.unsure))
                        Text("No").tag(WouldBuyAgain?.some(.no))
                    }
                    .pickerStyle(.segmented)
                }

                Section("Recommendation") {
                    VStack(alignment: .leading, spacing: PaktSpace.s2) {
                        HStack {
                            Text(recommendationLabel)
                                .font(.pakt(.heading))
                                .foregroundStyle(recommendationColor)
                            Spacer()
                            Text(String(format: "Score %.2f", output.score))
                                .font(.pakt(.small).monospacedDigit())
                                .foregroundStyle(Color.paktMutedForeground)
                        }
                        if !output.reasons.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(output.reasons, id: \.self) { reason in
                                    Text("• \(reason)")
                                        .font(.pakt(.small))
                                        .foregroundStyle(Color.paktMutedForeground)
                                }
                            }
                        }
                        PaktButton(applyLabel, action: apply)
                            .padding(.top, PaktSpace.s1)
                            .disabled(output.recommendation == .tossUp)
                            .opacity(output.recommendation == .tossUp ? 0.6 : 1)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paktBackground)
            .navigationTitle("Decide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.paktMutedForeground)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: saveAnswers).fontWeight(.semibold)
                }
            }
            .onAppear(perform: seedFromItem)
        }
    }

    // MARK: - Derived

    private var inputs: Predictions.DecisionInputs {
        .init(
            lastUsedMonths: Int(lastUsedMonthsRaw),
            replacementCostUsd: replacementCostRaw,
            sentimental: sentimental,
            wouldBuyAgain: wouldBuy
        )
    }

    private var output: Predictions.DecisionOutput {
        Predictions.scoreDecision(inputs: inputs)
    }

    private var recommendationLabel: String {
        switch output.recommendation {
        case .keep:   return "Keep it — move with you"
        case .donate: return "Let it go — donate"
        case .tossUp: return "Too close to call"
        }
    }

    private var recommendationColor: Color {
        switch output.recommendation {
        case .keep:   return Color.paktMoving
        case .donate: return Color.paktDonate
        case .tossUp: return Color.paktMutedForeground
        }
    }

    private var applyLabel: String {
        switch output.recommendation {
        case .keep:   return "Apply — Moving"
        case .donate: return "Apply — Donate"
        case .tossUp: return "No clear call yet"
        }
    }

    private var lastUsedLabel: String {
        let months = Int(lastUsedMonthsRaw)
        switch months {
        case 0:      return "Used today"
        case 1...2:  return "About a month ago"
        case 3...5:  return "A few months ago"
        case 6...11: return "6 months+"
        case 12...23: return "A year or more"
        case 24...47: return "2–4 years"
        default:     return "4+ years"
        }
    }

    private var replacementCostLabel: String {
        let cost = Int(replacementCostRaw)
        if cost == 0 { return "Free / trivial" }
        return "≈ $\(cost)"
    }

    // MARK: - Actions

    private func seedFromItem() {
        if let m = item.decisionLastUsedMonths { lastUsedMonthsRaw = Double(m) }
        if let c = item.decisionReplacementCostUsd { replacementCostRaw = c }
        sentimental = item.decisionSentimental
        wouldBuy = item.wouldBuyAgain
    }

    private func saveAnswers() {
        writeAnswers()
        try? context.save()
        dismiss()
    }

    private func apply() {
        writeAnswers()
        switch output.recommendation {
        case .keep:   item.disposition = .moving
        case .donate: item.disposition = .donate
        case .tossUp: break
        }
        item.updatedAt = Date()
        try? context.save()
        dismiss()
    }

    private func writeAnswers() {
        item.decisionLastUsedMonths = Int(lastUsedMonthsRaw)
        item.decisionReplacementCostUsd = replacementCostRaw
        item.decisionSentimental = sentimental
        item.wouldBuyAgain = wouldBuy
        item.decisionScore = output.score
    }
}
