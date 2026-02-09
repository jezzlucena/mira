import Combine
import Foundation
import HealthKit

/// Manages HealthKit integration for correlation analysis
/// Reads heart rate, sleep, and steps data to correlate with habits
public final class HealthKitManager: ObservableObject {
    private let healthStore: HKHealthStore?

    @Published public private(set) var isAuthorized = false
    @Published public private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined

    // Data types we want to read
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        return types
    }()

    public init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
        } else {
            self.healthStore = nil
        }
    }

    // MARK: - Authorization

    /// Checks if HealthKit is available on this device
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Requests authorization to read health data
    @MainActor
    public func requestAuthorization() async throws {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)

        // Check authorization status for heart rate as proxy
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let status = healthStore.authorizationStatus(for: heartRateType)
            await MainActor.run {
                self.authorizationStatus = status
                self.isAuthorized = status == .sharingAuthorized
            }
        }
    }

    /// Checks current authorization status
    @MainActor
    public func checkAuthorization() {
        guard let healthStore = healthStore,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            authorizationStatus = .notDetermined
            isAuthorized = false
            return
        }

        let status = healthStore.authorizationStatus(for: heartRateType)
        authorizationStatus = status
        // Note: For read-only, we can't reliably check if authorized
        // sharingAuthorized indicates they interacted with the prompt
        isAuthorized = status != .notDetermined
    }

    // MARK: - Heart Rate

    /// Fetches heart rate data around a specific timestamp
    public func getHeartRate(
        around date: Date,
        windowMinutes: Int = 30
    ) async throws -> [HeartRateSample] {
        guard let healthStore = healthStore,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.notAvailable
        }

        let startDate = Calendar.current.date(byAdding: .minute, value: -windowMinutes, to: date)!
        let endDate = Calendar.current.date(byAdding: .minute, value: windowMinutes, to: date)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let heartRateSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HeartRateSample(
                        date: sample.startDate,
                        beatsPerMinute: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    )
                } ?? []

                continuation.resume(returning: heartRateSamples)
            }

            healthStore.execute(query)
        }
    }

    /// Gets average heart rate for a time range
    public func getAverageHeartRate(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let healthStore = healthStore,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.notAvailable
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let average = statistics?.averageQuantity()?.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                continuation.resume(returning: average)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Steps

    /// Gets step count for a date
    public func getSteps(for date: Date) async throws -> Int {
        guard let healthStore = healthStore,
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.notAvailable
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }

            healthStore.execute(query)
        }
    }

    /// Gets daily step counts for a range of days
    public func getSteps(forLastDays days: Int) async throws -> [Date: Int] {
        guard let healthStore = healthStore,
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.notAvailable
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!

        var interval = DateComponents()
        interval.day = 1

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var stepsByDay: [Date: Int] = [:]

                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    stepsByDay[statistics.startDate] = steps
                }

                continuation.resume(returning: stepsByDay)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Sleep

    /// Gets sleep data for a night (checks previous day's evening to current morning)
    public func getSleepData(for date: Date) async throws -> SleepSummary? {
        guard let healthStore = healthStore,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.notAvailable
        }

        let calendar = Calendar.current
        // Sleep typically starts the evening before
        let startDate = calendar.date(byAdding: .hour, value: -12, to: calendar.startOfDay(for: date))!
        let endDate = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date))!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample],
                      !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                var totalSleepMinutes: Double = 0
                var deepSleepMinutes: Double = 0
                var remSleepMinutes: Double = 0
                var sleepStart: Date?
                var sleepEnd: Date?

                for sample in categorySamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60

                    if let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        switch value {
                        case .asleepCore, .asleepUnspecified:
                            totalSleepMinutes += duration
                        case .asleepDeep:
                            totalSleepMinutes += duration
                            deepSleepMinutes += duration
                        case .asleepREM:
                            totalSleepMinutes += duration
                            remSleepMinutes += duration
                        default:
                            break
                        }
                    }

                    if sleepStart == nil || sample.startDate < sleepStart! {
                        sleepStart = sample.startDate
                    }
                    if sleepEnd == nil || sample.endDate > sleepEnd! {
                        sleepEnd = sample.endDate
                    }
                }

                let summary = SleepSummary(
                    date: date,
                    totalMinutes: totalSleepMinutes,
                    deepSleepMinutes: deepSleepMinutes,
                    remSleepMinutes: remSleepMinutes,
                    sleepStart: sleepStart,
                    sleepEnd: sleepEnd
                )

                continuation.resume(returning: summary)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Resting Heart Rate

    /// Gets resting heart rate for a date
    public func getRestingHeartRate(for date: Date) async throws -> Double? {
        guard let healthStore = healthStore,
              let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.notAvailable
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: restingHRType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let average = statistics?.averageQuantity()?.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                continuation.resume(returning: average)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - HRV (Heart Rate Variability)

    /// Gets average HRV for a date
    public func getAverageHRV(for date: Date) async throws -> Double? {
        guard let healthStore = healthStore,
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.notAvailable
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let average = statistics?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: average)
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Supporting Types

public enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case queryFailed

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access has not been authorized"
        case .queryFailed:
            return "Failed to query HealthKit data"
        }
    }
}

public struct HeartRateSample: Identifiable {
    public let id = UUID()
    public let date: Date
    public let beatsPerMinute: Double
}

public struct SleepSummary: Identifiable {
    public let id = UUID()
    public let date: Date
    public let totalMinutes: Double
    public let deepSleepMinutes: Double
    public let remSleepMinutes: Double
    public let sleepStart: Date?
    public let sleepEnd: Date?

    public var totalHours: Double {
        totalMinutes / 60
    }

    public var qualityScore: Double {
        // Simple quality score based on deep sleep and REM proportions
        guard totalMinutes > 0 else { return 0 }
        let deepRatio = deepSleepMinutes / totalMinutes
        let remRatio = remSleepMinutes / totalMinutes
        // Ideal: ~20% deep, ~25% REM
        return min(1.0, (deepRatio / 0.2 + remRatio / 0.25) / 2)
    }
}
