import Testing
import Foundation
@testable import MiraKit

@Suite("HealthKit Types Tests")
struct HealthKitTypesTests {

    @Test("HeartRateSample creation")
    func testHeartRateSample() {
        let sample = HeartRateSample(
            date: Date(),
            beatsPerMinute: 72.0
        )

        #expect(sample.beatsPerMinute == 72.0)
        #expect(sample.id != UUID()) // Has unique ID
    }

    @Test("SleepSummary calculations")
    func testSleepSummary() {
        let summary = SleepSummary(
            date: Date(),
            totalMinutes: 480, // 8 hours
            deepSleepMinutes: 90,
            remSleepMinutes: 120,
            sleepStart: Date(),
            sleepEnd: Date()
        )

        #expect(summary.totalHours == 8.0)
        #expect(summary.totalMinutes == 480)
        #expect(summary.deepSleepMinutes == 90)
        #expect(summary.remSleepMinutes == 120)
    }

    @Test("SleepSummary quality score calculation")
    func testSleepQualityScore() {
        // Ideal sleep: ~20% deep, ~25% REM
        let idealSleep = SleepSummary(
            date: Date(),
            totalMinutes: 480,
            deepSleepMinutes: 96,  // 20%
            remSleepMinutes: 120,  // 25%
            sleepStart: nil,
            sleepEnd: nil
        )

        // Quality score should be high (close to 1.0)
        #expect(idealSleep.qualityScore > 0.8)
    }

    @Test("SleepSummary quality score with poor sleep")
    func testPoorSleepQualityScore() {
        let poorSleep = SleepSummary(
            date: Date(),
            totalMinutes: 480,
            deepSleepMinutes: 20,  // Very low
            remSleepMinutes: 30,   // Very low
            sleepStart: nil,
            sleepEnd: nil
        )

        // Quality score should be low
        #expect(poorSleep.qualityScore < 0.5)
    }

    @Test("SleepSummary quality score with no sleep")
    func testNoSleepQualityScore() {
        let noSleep = SleepSummary(
            date: Date(),
            totalMinutes: 0,
            deepSleepMinutes: 0,
            remSleepMinutes: 0,
            sleepStart: nil,
            sleepEnd: nil
        )

        #expect(noSleep.qualityScore == 0)
    }
}

@Suite("HealthKitError Tests")
struct HealthKitErrorTests {

    @Test("Error descriptions")
    func testErrorDescriptions() {
        #expect(HealthKitError.notAvailable.errorDescription == "HealthKit is not available on this device")
        #expect(HealthKitError.notAuthorized.errorDescription == "HealthKit access has not been authorized")
        #expect(HealthKitError.queryFailed.errorDescription == "Failed to query HealthKit data")
    }
}

@Suite("SleepMoodCorrelation Tests")
struct SleepMoodCorrelationTests {

    @Test("Correlation data structure")
    func testSleepMoodCorrelation() {
        let correlation = SleepMoodCorrelation(
            correlation: 0.65,
            averageSleepHours: 7.5,
            averageMood: 4.2,
            sampleSize: 30
        )

        #expect(correlation.correlation == 0.65)
        #expect(correlation.averageSleepHours == 7.5)
        #expect(correlation.averageMood == 4.2)
        #expect(correlation.sampleSize == 30)
    }
}

@Suite("StepsMoodCorrelation Tests")
struct StepsMoodCorrelationTests {

    @Test("Correlation data structure")
    func testStepsMoodCorrelation() {
        let correlation = StepsMoodCorrelation(
            correlation: 0.45,
            averageSteps: 8500,
            averageMood: 4.0,
            sampleSize: 30
        )

        #expect(correlation.correlation == 0.45)
        #expect(correlation.averageSteps == 8500)
        #expect(correlation.averageMood == 4.0)
        #expect(correlation.sampleSize == 30)
    }
}
