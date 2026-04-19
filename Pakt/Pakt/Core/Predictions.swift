import Foundation

public enum Predictions {
    public static let boxVolumeCuFt: [RecommendedBoxType: Double] = [
        .small: 1.5,
        .medium: 3.0,
        .large: 4.5,
        .dishPack: 5.2,
        .wardrobe: 11.0,
        .tote: 2.4,
    ]

    public static let boxFillEfficiency: Double = 0.85
    public static let truckSafetyMargin: Double = 1.15
    public static let heavyItemThresholdLbs: Double = 150

    public static let furnitureCategoryIds: Set<String> = [
        "cat_furniture_small",
        "cat_furniture_medium",
        "cat_furniture_large",
        "cat_mattress_queen",
        "cat_mattress_king",
    ]

    public enum TruckSize: String, Codable, Sendable, CaseIterable {
        case ft10 = "10ft"
        case ft15 = "15ft"
        case ft20 = "20ft"
        case ft26 = "26ft"
        case oversized
    }

    public struct TruckEntry: Sendable {
        public let size: TruckSize
        public let cuft: Double
        public let rooms: String
    }

    public static let trucks: [TruckEntry] = [
        .init(size: .ft10, cuft: 402,  rooms: "studio / light 1BR"),
        .init(size: .ft15, cuft: 764,  rooms: "1–2 BR"),
        .init(size: .ft20, cuft: 1016, rooms: "2–3 BR"),
        .init(size: .ft26, cuft: 1682, rooms: "3–4 BR"),
    ]

    public struct PredictionItem: Sendable, Hashable {
        public let categoryId: String?
        public let quantity: Int
        public let volumeCuFt: Double
        public let weightLbs: Double
        public let recommendedBoxType: RecommendedBoxType
        public let disposition: Disposition

        public init(
            categoryId: String?,
            quantity: Int,
            volumeCuFt: Double,
            weightLbs: Double,
            recommendedBoxType: RecommendedBoxType,
            disposition: Disposition
        ) {
            self.categoryId = categoryId
            self.quantity = quantity
            self.volumeCuFt = volumeCuFt
            self.weightLbs = weightLbs
            self.recommendedBoxType = recommendedBoxType
            self.disposition = disposition
        }
    }

    public struct BoxCountResult: Sendable, Hashable {
        public var boxesByType: [RecommendedBoxType: Int]
        public var looseFurnitureCuFt: Double
        public var totalBoxCuFt: Double
        public var totalBoxCount: Int
    }

    public static func predictBoxCounts(items: [PredictionItem]) -> BoxCountResult {
        let packingDispositions: Set<Disposition> = [.moving, .storage]
        let packable = items.filter { packingDispositions.contains($0.disposition) && $0.recommendedBoxType != .none }
        let loose    = items.filter { packingDispositions.contains($0.disposition) && $0.recommendedBoxType == .none }

        let packTypes: [RecommendedBoxType] = [.small, .medium, .large, .dishPack, .wardrobe, .tote]

        var volumesByType: [RecommendedBoxType: Double] = Dictionary(uniqueKeysWithValues: packTypes.map { ($0, 0) })
        for item in packable {
            volumesByType[item.recommendedBoxType, default: 0] += item.volumeCuFt * Double(item.quantity)
        }

        var boxesByType: [RecommendedBoxType: Int] = Dictionary(uniqueKeysWithValues: packTypes.map { ($0, 0) })
        var totalBoxCuFt: Double = 0
        for key in packTypes {
            let capacity = (boxVolumeCuFt[key] ?? 0) * boxFillEfficiency
            let v = volumesByType[key] ?? 0
            let n = v > 0 && capacity > 0 ? Int((v / capacity).rounded(.up)) : 0
            boxesByType[key] = n
            totalBoxCuFt += Double(n) * (boxVolumeCuFt[key] ?? 0)
        }

        let looseFurnitureCuFt = loose.reduce(0.0) { $0 + $1.volumeCuFt * Double($1.quantity) }
        let totalBoxCount = boxesByType.values.reduce(0, +)

        return BoxCountResult(
            boxesByType: boxesByType,
            looseFurnitureCuFt: looseFurnitureCuFt,
            totalBoxCuFt: totalBoxCuFt,
            totalBoxCount: totalBoxCount
        )
    }

    public struct TruckRecommendation: Sendable, Hashable {
        public var size: TruckSize
        public var cuft: Double?
        public var totalVolumeCuFt: Double
        public var sizedVolumeCuFt: Double
        public var note: String
        public var heavyItemCount: Int
    }

    public static func recommendTruck(items: [PredictionItem]) -> TruckRecommendation {
        let counts = predictBoxCounts(items: items)
        let totalVolume = counts.totalBoxCuFt + counts.looseFurnitureCuFt
        let sizedVolume = totalVolume * truckSafetyMargin

        let packingDispositions: Set<Disposition> = [.moving, .storage]
        let heavyItemCount = items.filter {
            packingDispositions.contains($0.disposition) && $0.weightLbs >= heavyItemThresholdLbs
        }.count

        if let match = trucks.first(where: { $0.cuft >= sizedVolume }) {
            return TruckRecommendation(
                size: match.size,
                cuft: match.cuft,
                totalVolumeCuFt: totalVolume,
                sizedVolumeCuFt: sizedVolume,
                note: "Fits in a \(match.size.rawValue) truck (\(match.rooms)).",
                heavyItemCount: heavyItemCount
            )
        }
        return TruckRecommendation(
            size: .oversized,
            cuft: nil,
            totalVolumeCuFt: totalVolume,
            sizedVolumeCuFt: sizedVolume,
            note: "Too much for a single 26ft truck — consider a second trip, pods, or a professional mover.",
            heavyItemCount: heavyItemCount
        )
    }

    public struct DecisionInputs: Sendable, Hashable {
        public var lastUsedMonths: Int?
        public var replacementCostUsd: Double?
        public var sentimental: Bool?
        public var wouldBuyAgain: WouldBuyAgain?

        public init(
            lastUsedMonths: Int? = nil,
            replacementCostUsd: Double? = nil,
            sentimental: Bool? = nil,
            wouldBuyAgain: WouldBuyAgain? = nil
        ) {
            self.lastUsedMonths = lastUsedMonths
            self.replacementCostUsd = replacementCostUsd
            self.sentimental = sentimental
            self.wouldBuyAgain = wouldBuyAgain
        }
    }

    public enum DecisionRecommendation: String, Sendable, Codable {
        case keep
        case donate
        case tossUp = "toss_up"
    }

    public struct DecisionOutput: Sendable, Hashable {
        public var score: Double
        public var recommendation: DecisionRecommendation
        public var reasons: [String]
    }

    private static let decisionWeights = (
        lastUsed: 0.3,
        replacementCost: 0.15,
        sentimental: 0.25,
        wouldBuyAgain: 0.3
    )

    private static func mapLastUsed(_ months: Int) -> Double {
        let m = Double(months)
        if m <= 0 { return 1 }
        if m <= 6 { return 1 - ((m - 0) / 6) * 0.7 }
        if m <= 12 { return 0.3 - ((m - 6) / 6) * 0.3 }
        if m <= 24 { return 0 - ((m - 12) / 12) * 0.5 }
        if m <= 36 { return -0.5 - ((m - 24) / 12) * 0.5 }
        return -1
    }

    private static func mapReplacementCost(_ usd: Double) -> Double {
        if usd < 25 { return -0.5 }
        if usd < 100 { return 0 }
        if usd < 500 { return 0.5 }
        return 1
    }

    private static func mapWouldBuyAgain(_ v: WouldBuyAgain) -> Double {
        switch v { case .yes: return 1; case .no: return -1; case .unsure: return -0.2 }
    }

    public static func scoreDecision(inputs: DecisionInputs) -> DecisionOutput {
        var weighted: [(score: Double, weight: Double)] = []
        var reasons: [String] = []

        if let m = inputs.lastUsedMonths {
            weighted.append((mapLastUsed(m), decisionWeights.lastUsed))
            if m >= 24 { reasons.append("Unused for \(m)+ months") }
            else if m <= 3 { reasons.append("Used recently") }
        }
        if let c = inputs.replacementCostUsd {
            weighted.append((mapReplacementCost(c), decisionWeights.replacementCost))
            if c >= 500 { reasons.append("Expensive to replace") }
            else if c < 25 { reasons.append("Cheap to replace") }
        }
        if let s = inputs.sentimental {
            weighted.append((s ? 0.8 : 0, decisionWeights.sentimental))
            if s { reasons.append("Sentimental value") }
        }
        if let w = inputs.wouldBuyAgain {
            weighted.append((mapWouldBuyAgain(w), decisionWeights.wouldBuyAgain))
            if w == .no { reasons.append("Wouldn't buy again") }
            else if w == .yes { reasons.append("Would buy again") }
        }

        if weighted.isEmpty {
            return DecisionOutput(score: 0, recommendation: .tossUp, reasons: ["No answers provided"])
        }

        let totalWeight = weighted.reduce(0.0) { $0 + $1.weight }
        let rawScore = weighted.reduce(0.0) { $0 + $1.score * $1.weight }
        let rounded = (rawScore / totalWeight * 1000).rounded() / 1000

        let recommendation: DecisionRecommendation
        if rounded >= 0.35 { recommendation = .keep }
        else if rounded <= -0.35 { recommendation = .donate }
        else { recommendation = .tossUp }

        return DecisionOutput(score: rounded, recommendation: recommendation, reasons: reasons)
    }
}
