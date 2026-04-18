import PaktCore
import SwiftData
import SwiftUI

struct DashboardView: View {
    let move: Move

    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaktSpace.s4) {
                header
                countsGrid
                predictionsCard
                Spacer(minLength: 80)
            }
            .padding(PaktSpace.s4)
        }
        .background(Color.paktBackground)
        .navigationTitle(move.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: PaktSpace.s2) {
            if let date = move.plannedMoveDate {
                Text("Moving \(date.formatted(date: .long, time: .omitted))")
                    .font(.pakt(.body))
                    .foregroundStyle(Color.paktMutedForeground)
            }
            if let origin = move.originAddress, !origin.isEmpty {
                Text("From \(origin)")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
            if let dest = move.destinationAddress, !dest.isEmpty {
                Text("To \(dest)")
                    .font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
            }
        }
    }

    private var countsGrid: some View {
        let live = liveItems
        return LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: PaktSpace.s3) {
            StatCard(title: "Items",     value: "\(live.count)")
            StatCard(title: "Moving",    value: "\(live.filter { $0.disposition == .moving }.count)")
            StatCard(title: "Undecided", value: "\(live.filter { $0.disposition == .undecided }.count)")
            StatCard(title: "Boxes",     value: "\(liveBoxes.count)")
        }
    }

    private var predictionsCard: some View {
        let rec = truckRecommendation
        let counts = boxCounts
        return PaktCard {
            VStack(alignment: .leading, spacing: PaktSpace.s3) {
                Text("Predicted packing").font(.pakt(.heading))
                if counts.totalBoxCount == 0 {
                    Text("Add items to see predicted box counts.")
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                } else {
                    ForEach(RecommendedBoxType.allCases.filter { $0 != .none }, id: \.self) { type in
                        let n = counts.boxesByType[type] ?? 0
                        if n > 0 {
                            HStack {
                                Text(label(for: type)).font(.pakt(.body))
                                    .foregroundStyle(Color.paktForeground)
                                Spacer()
                                PaktBadge("\(n)", tone: .secondary)
                            }
                        }
                    }
                }

                Divider().background(Color.paktBorder)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Truck size").font(.pakt(.bodyMedium))
                            .foregroundStyle(Color.paktForeground)
                        Spacer()
                        PaktBadge(rec.size.rawValue, tone: .default)
                    }
                    Text(rec.note)
                        .font(.pakt(.small))
                        .foregroundStyle(Color.paktMutedForeground)
                    if rec.heavyItemCount > 0 {
                        Text("\(rec.heavyItemCount) heavy item\(rec.heavyItemCount == 1 ? "" : "s") — plan for movers.")
                            .font(.pakt(.small))
                            .foregroundStyle(Color.paktDestructive)
                    }
                }
            }
        }
    }

    // MARK: - Data helpers

    private var liveItems: [Item] {
        (move.items ?? []).filter { $0.deletedAt == nil }
    }

    private var liveBoxes: [Box] {
        (move.boxes ?? []).filter { $0.deletedAt == nil }
    }

    private var predictionInputs: [Predictions.PredictionItem] {
        liveItems.map { item in
            Predictions.PredictionItem(
                categoryId: item.categoryId,
                quantity: item.quantity,
                volumeCuFt: item.volumeCuFtOverride ?? 0.5,  // placeholder until categories ship
                weightLbs: item.weightLbsOverride ?? 5,
                recommendedBoxType: .medium,
                disposition: item.disposition
            )
        }
    }

    private var boxCounts: Predictions.BoxCountResult {
        Predictions.predictBoxCounts(items: predictionInputs)
    }

    private var truckRecommendation: Predictions.TruckRecommendation {
        Predictions.recommendTruck(items: predictionInputs)
    }

    private func label(for type: RecommendedBoxType) -> String {
        switch type {
        case .small:    return "Small"
        case .medium:   return "Medium"
        case .large:    return "Large"
        case .dishPack: return "Dish pack"
        case .wardrobe: return "Wardrobe"
        case .tote:     return "Tote"
        case .none:     return "Loose"
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        PaktCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.pakt(.small))
                    .foregroundStyle(Color.paktMutedForeground)
                Text(value).font(.pakt(.title))
                    .foregroundStyle(Color.paktForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
