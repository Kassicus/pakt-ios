import XCTest
@testable import PaktCore

final class PredictionsTests: XCTestCase {
    func testEmpty() {
        let r = Predictions.predictBoxCounts(items: [])
        XCTAssertEqual(r.totalBoxCount, 0)
        XCTAssertEqual(r.totalBoxCuFt, 0)
        XCTAssertEqual(r.looseFurnitureCuFt, 0)
    }

    func testOnlyUndecidedSkipsCounting() {
        let items = [
            Predictions.PredictionItem(categoryId: "cat_kitchen", quantity: 10,
                                       volumeCuFt: 0.3, weightLbs: 2,
                                       recommendedBoxType: .medium,
                                       disposition: .undecided),
        ]
        let r = Predictions.predictBoxCounts(items: items)
        XCTAssertEqual(r.totalBoxCount, 0)
    }

    func testCeilingFill() {
        // 5 items × 0.5 cuft = 2.5 cuft in medium (3.0 × 0.85 = 2.55 capacity) → 1 box
        let items = [
            Predictions.PredictionItem(categoryId: nil, quantity: 5,
                                       volumeCuFt: 0.5, weightLbs: 3,
                                       recommendedBoxType: .medium,
                                       disposition: .moving),
        ]
        let r = Predictions.predictBoxCounts(items: items)
        XCTAssertEqual(r.boxesByType[.medium], 1)
        XCTAssertEqual(r.totalBoxCuFt, 3.0, accuracy: 0.001)
    }

    func testLooseFurnitureStaysLoose() {
        let items = [
            Predictions.PredictionItem(categoryId: "cat_furniture_large", quantity: 1,
                                       volumeCuFt: 25, weightLbs: 180,
                                       recommendedBoxType: .none,
                                       disposition: .moving),
        ]
        let r = Predictions.predictBoxCounts(items: items)
        XCTAssertEqual(r.totalBoxCount, 0)
        XCTAssertEqual(r.looseFurnitureCuFt, 25, accuracy: 0.001)
    }

    func testTruckRecommendationMatchesFirstFit() {
        // 100 × 2.0 cuft mediums → ~237 cuft of boxes → sized ≈ 272 → 10ft (402) fits.
        let items = (0..<100).map { _ in
            Predictions.PredictionItem(categoryId: nil, quantity: 1,
                                       volumeCuFt: 2.0, weightLbs: 10,
                                       recommendedBoxType: .medium,
                                       disposition: .moving)
        }
        let rec = Predictions.recommendTruck(items: items)
        XCTAssertEqual(rec.size, .ft10)
        XCTAssertGreaterThan(rec.sizedVolumeCuFt, rec.totalVolumeCuFt)
    }

    func testTruckRecommendationEscalates() {
        // 300 mediums → ~712 cuft boxes → sized ≈ 819 → exceeds 15ft (764), fits 20ft (1016).
        let items = (0..<300).map { _ in
            Predictions.PredictionItem(categoryId: nil, quantity: 1,
                                       volumeCuFt: 2.0, weightLbs: 10,
                                       recommendedBoxType: .medium,
                                       disposition: .moving)
        }
        let rec = Predictions.recommendTruck(items: items)
        XCTAssertEqual(rec.size, .ft20)
    }

    func testOversizedWhenOverLargestTruck() {
        let items = [
            Predictions.PredictionItem(categoryId: nil, quantity: 1000,
                                       volumeCuFt: 2.0, weightLbs: 10,
                                       recommendedBoxType: .medium,
                                       disposition: .moving),
        ]
        let rec = Predictions.recommendTruck(items: items)
        XCTAssertEqual(rec.size, .oversized)
        XCTAssertNil(rec.cuft)
    }

    func testHeavyItemCount() {
        let items = [
            Predictions.PredictionItem(categoryId: nil, quantity: 1,
                                       volumeCuFt: 5, weightLbs: 200,
                                       recommendedBoxType: .none,
                                       disposition: .moving),
            Predictions.PredictionItem(categoryId: nil, quantity: 1,
                                       volumeCuFt: 1, weightLbs: 5,
                                       recommendedBoxType: .small,
                                       disposition: .moving),
            Predictions.PredictionItem(categoryId: nil, quantity: 1,
                                       volumeCuFt: 5, weightLbs: 300,
                                       recommendedBoxType: .none,
                                       disposition: .donate),   // donated, not counted
        ]
        let rec = Predictions.recommendTruck(items: items)
        XCTAssertEqual(rec.heavyItemCount, 1)
    }

    func testDecisionNoAnswers() {
        let out = Predictions.scoreDecision(inputs: .init())
        XCTAssertEqual(out.recommendation, .tossUp)
        XCTAssertEqual(out.score, 0)
    }

    func testDecisionDonateProfile() {
        let out = Predictions.scoreDecision(inputs: .init(
            lastUsedMonths: 36,
            replacementCostUsd: 20,
            sentimental: false,
            wouldBuyAgain: .no
        ))
        XCTAssertEqual(out.recommendation, .donate)
        XCTAssertTrue(out.reasons.contains { $0.contains("Unused") })
    }

    func testDecisionKeepProfile() {
        let out = Predictions.scoreDecision(inputs: .init(
            lastUsedMonths: 1,
            replacementCostUsd: 800,
            sentimental: true,
            wouldBuyAgain: .yes
        ))
        XCTAssertEqual(out.recommendation, .keep)
    }
}
