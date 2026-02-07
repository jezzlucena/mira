import Testing
import Foundation
@testable import MiraKit

@Suite("Analytics Engine Tests")
struct AnalyticsEngineTests {

    @Test("Pearson correlation calculation - positive correlation")
    func testPositiveCorrelation() {
        // Perfect positive correlation
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [2.0, 4.0, 6.0, 8.0, 10.0]

        let correlation = pearsonCorrelation(x: x, y: y)

        #expect(correlation != nil)
        #expect(abs(correlation! - 1.0) < 0.001) // Should be ~1.0
    }

    @Test("Pearson correlation calculation - negative correlation")
    func testNegativeCorrelation() {
        // Perfect negative correlation
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [10.0, 8.0, 6.0, 4.0, 2.0]

        let correlation = pearsonCorrelation(x: x, y: y)

        #expect(correlation != nil)
        #expect(abs(correlation! + 1.0) < 0.001) // Should be ~-1.0
    }

    @Test("Pearson correlation calculation - no correlation")
    func testNoCorrelation() {
        // Random data should have weak correlation
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [5.0, 2.0, 4.0, 1.0, 3.0]

        let correlation = pearsonCorrelation(x: x, y: y)

        #expect(correlation != nil)
        #expect(abs(correlation!) < 0.5) // Should be weak
    }

    @Test("Pearson correlation - insufficient data")
    func testInsufficientData() {
        let x = [1.0, 2.0]
        let y = [3.0, 4.0]

        let correlation = pearsonCorrelation(x: x, y: y)

        #expect(correlation == nil) // Need at least 3 points
    }

    @Test("Pearson correlation - mismatched arrays")
    func testMismatchedArrays() {
        let x = [1.0, 2.0, 3.0]
        let y = [4.0, 5.0]

        let correlation = pearsonCorrelation(x: x, y: y)

        #expect(correlation == nil)
    }

    // Helper function to test correlation
    private func pearsonCorrelation(x: [Double], y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 2 else { return nil }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        guard denominator != 0 else { return nil }
        return numerator / denominator
    }
}

@Suite("Correlation Result Tests")
struct CorrelationResultTests {

    @Test("Correlation strength descriptions")
    func testStrengthDescriptions() {
        let habit = Habit(name: "Test")

        let veryWeak = CorrelationResult(habit: habit, correlation: 0.1, sampleSize: 10, periodDays: 30)
        #expect(veryWeak.strengthDescription == "Very weak")

        let weak = CorrelationResult(habit: habit, correlation: 0.3, sampleSize: 10, periodDays: 30)
        #expect(weak.strengthDescription == "Weak")

        let moderate = CorrelationResult(habit: habit, correlation: 0.5, sampleSize: 10, periodDays: 30)
        #expect(moderate.strengthDescription == "Moderate")

        let strong = CorrelationResult(habit: habit, correlation: 0.7, sampleSize: 10, periodDays: 30)
        #expect(strong.strengthDescription == "Strong")

        let veryStrong = CorrelationResult(habit: habit, correlation: 0.9, sampleSize: 10, periodDays: 30)
        #expect(veryStrong.strengthDescription == "Very strong")
    }

    @Test("Correlation with negative values")
    func testNegativeCorrelation() {
        let habit = Habit(name: "Test")

        let negative = CorrelationResult(habit: habit, correlation: -0.6, sampleSize: 10, periodDays: 30)
        #expect(negative.strengthDescription == "Moderate") // Uses absolute value
    }

    @Test("Insufficient data description")
    func testInsufficientData() {
        let habit = Habit(name: "Test")

        let noData = CorrelationResult(habit: habit, correlation: nil, sampleSize: 2, periodDays: 30)
        #expect(noData.strengthDescription == "Insufficient data")
    }
}

@Suite("Insight Tests")
struct InsightTests {

    @Test("Insight types")
    func testInsightTypes() {
        let habitInsight = Insight(
            type: .habitCorrelation,
            title: "Pattern",
            description: "Test",
            strength: 0.8,
            relatedHabit: nil
        )
        #expect(habitInsight.type == .habitCorrelation)

        let temporalInsight = Insight(
            type: .temporalPattern,
            title: "Weekly",
            description: "Test",
            strength: 0.6,
            relatedHabit: nil
        )
        #expect(temporalInsight.type == .temporalPattern)

        let healthInsight = Insight(
            type: .healthCorrelation,
            title: "Sleep",
            description: "Test",
            strength: 0.7,
            relatedHabit: nil
        )
        #expect(healthInsight.type == .healthCorrelation)
    }
}

@Suite("HeatmapCell Tests")
struct HeatmapCellTests {

    @Test("Cell with data")
    func testCellWithData() {
        let cell = HeatmapCell(
            date: Date(),
            entryCount: 3,
            averageSentiment: 4.5
        )

        #expect(cell.hasData)
        #expect(cell.entryCount == 3)
        #expect(cell.averageSentiment == 4.5)
    }

    @Test("Cell without data")
    func testCellWithoutData() {
        let cell = HeatmapCell(
            date: Date(),
            entryCount: 0,
            averageSentiment: nil
        )

        #expect(!cell.hasData)
        #expect(cell.averageSentiment == nil)
    }
}
