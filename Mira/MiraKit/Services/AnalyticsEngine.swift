import Combine
import Foundation
import SwiftData

/// Analytics engine for correlation analysis between habits, mood, and health data
/// This is Mira's key differentiator - helping users discover patterns
@MainActor
public final class AnalyticsEngine: ObservableObject {
    private let modelContext: ModelContext
    private let healthKitManager: HealthKitManager

    public init(modelContext: ModelContext, healthKitManager: HealthKitManager = HealthKitManager()) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
    }

    // MARK: - Sentiment Analysis

    /// Calculates average sentiment by day of week
    public func sentimentByDayOfWeek(forLastDays days: Int = 30) throws -> [Int: Double] {
        let entries = try fetchAllEntries(forLastDays: days)
        let sentimentRecords = try fetchAllSentimentRecords(forLastDays: days)

        var sentimentsByDay: [Int: [Int]] = [:]

        // Process habit entries
        for entry in entries {
            let weekday = Calendar.current.component(.weekday, from: entry.timestamp)
            sentimentsByDay[weekday, default: []].append(entry.sentiment)
        }

        // Process standalone sentiment records
        for record in sentimentRecords {
            let weekday = Calendar.current.component(.weekday, from: record.timestamp)
            sentimentsByDay[weekday, default: []].append(record.sentiment)
        }

        // Calculate averages
        var averages: [Int: Double] = [:]
        for (day, sentiments) in sentimentsByDay {
            guard !sentiments.isEmpty else { continue }
            averages[day] = Double(sentiments.reduce(0, +)) / Double(sentiments.count)
        }

        return averages
    }

    /// Calculates average sentiment by hour of day
    public func sentimentByHourOfDay(forLastDays days: Int = 30) throws -> [Int: Double] {
        let entries = try fetchAllEntries(forLastDays: days)
        let sentimentRecords = try fetchAllSentimentRecords(forLastDays: days)

        var sentimentsByHour: [Int: [Int]] = [:]

        for entry in entries {
            let hour = Calendar.current.component(.hour, from: entry.timestamp)
            sentimentsByHour[hour, default: []].append(entry.sentiment)
        }

        for record in sentimentRecords {
            let hour = Calendar.current.component(.hour, from: record.timestamp)
            sentimentsByHour[hour, default: []].append(record.sentiment)
        }

        var averages: [Int: Double] = [:]
        for (hour, sentiments) in sentimentsByHour {
            guard !sentiments.isEmpty else { continue }
            averages[hour] = Double(sentiments.reduce(0, +)) / Double(sentiments.count)
        }

        return averages
    }

    /// Gets sentiment trend over time (daily averages)
    public func sentimentTrend(forLastDays days: Int = 30) throws -> [Date: Double] {
        let entries = try fetchAllEntries(forLastDays: days)
        let sentimentRecords = try fetchAllSentimentRecords(forLastDays: days)

        var sentimentsByDay: [Date: [Int]] = [:]
        let calendar = Calendar.current

        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            sentimentsByDay[day, default: []].append(entry.sentiment)
        }

        for record in sentimentRecords {
            let day = calendar.startOfDay(for: record.timestamp)
            sentimentsByDay[day, default: []].append(record.sentiment)
        }

        var trend: [Date: Double] = [:]
        for (day, sentiments) in sentimentsByDay {
            guard !sentiments.isEmpty else { continue }
            trend[day] = Double(sentiments.reduce(0, +)) / Double(sentiments.count)
        }

        return trend
    }

    // MARK: - Habit Correlations

    /// Calculates correlation between a habit and mood
    /// Returns a value between -1 (negative correlation) and 1 (positive correlation)
    public func habitMoodCorrelation(for habit: Habit, days: Int = 30) throws -> CorrelationResult {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!

        // Get entries for this habit
        let habitEntries = habit.entries.filter { $0.timestamp >= startDate }

        // Get all sentiment data for comparison
        let allEntries = try fetchAllEntries(forLastDays: days)
        let sentimentRecords = try fetchAllSentimentRecords(forLastDays: days)

        // Group by day
        var habitDays: [Date: [Int]] = [:]
        var moodDays: [Date: [Int]] = [:]

        for entry in habitEntries {
            let day = calendar.startOfDay(for: entry.timestamp)
            habitDays[day, default: []].append(entry.sentiment)
        }

        for entry in allEntries {
            let day = calendar.startOfDay(for: entry.timestamp)
            moodDays[day, default: []].append(entry.sentiment)
        }

        for record in sentimentRecords {
            let day = calendar.startOfDay(for: record.timestamp)
            moodDays[day, default: []].append(record.sentiment)
        }

        // Calculate averages for days where we have both
        var habitAvgs: [Double] = []
        var moodAvgs: [Double] = []

        for (day, habitSentiments) in habitDays {
            guard let moodSentiments = moodDays[day], !moodSentiments.isEmpty else { continue }

            let habitAvg = Double(habitSentiments.reduce(0, +)) / Double(habitSentiments.count)
            let moodAvg = Double(moodSentiments.reduce(0, +)) / Double(moodSentiments.count)

            habitAvgs.append(habitAvg)
            moodAvgs.append(moodAvg)
        }

        // Calculate Pearson correlation
        let correlation = pearsonCorrelation(x: habitAvgs, y: moodAvgs)

        return CorrelationResult(
            habit: habit,
            correlation: correlation,
            sampleSize: habitAvgs.count,
            periodDays: days
        )
    }

    /// Finds habits most correlated with high/low mood
    public func findMoodCorrelations(days: Int = 30) throws -> [CorrelationResult] {
        let habits = try fetchAllHabits()
        var results: [CorrelationResult] = []

        for habit in habits {
            let result = try habitMoodCorrelation(for: habit, days: days)
            if result.sampleSize >= 3 { // Need at least 3 data points
                results.append(result)
            }
        }

        // Sort by absolute correlation strength
        return results.sorted { abs($0.correlation ?? 0) > abs($1.correlation ?? 0) }
    }

    // MARK: - Health Correlations

    /// Correlates sleep quality with mood
    public func sleepMoodCorrelation(days: Int = 30) async throws -> SleepMoodCorrelation? {
        guard healthKitManager.isAvailable else { return nil }

        let calendar = Calendar.current
        var sleepScores: [Double] = []
        var moodScores: [Double] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            // Get sleep from previous night
            if let sleep = try? await healthKitManager.getSleepData(for: date) {
                // Get mood for this day
                let dayMood = try getMoodForDay(date)
                if let avgMood = dayMood {
                    sleepScores.append(sleep.totalHours)
                    moodScores.append(avgMood)
                }
            }
        }

        guard sleepScores.count >= 3 else { return nil }

        let correlation = pearsonCorrelation(x: sleepScores, y: moodScores)

        return SleepMoodCorrelation(
            correlation: correlation,
            averageSleepHours: sleepScores.reduce(0, +) / Double(sleepScores.count),
            averageMood: moodScores.reduce(0, +) / Double(moodScores.count),
            sampleSize: sleepScores.count
        )
    }

    /// Correlates step count with mood
    public func stepsMoodCorrelation(days: Int = 30) async throws -> StepsMoodCorrelation? {
        guard healthKitManager.isAvailable else { return nil }

        let stepsByDay = try await healthKitManager.getSteps(forLastDays: days)

        var steps: [Double] = []
        var moods: [Double] = []

        for (date, stepCount) in stepsByDay {
            if let dayMood = try getMoodForDay(date) {
                steps.append(Double(stepCount))
                moods.append(dayMood)
            }
        }

        guard steps.count >= 3 else { return nil }

        let correlation = pearsonCorrelation(x: steps, y: moods)

        return StepsMoodCorrelation(
            correlation: correlation,
            averageSteps: steps.reduce(0, +) / Double(steps.count),
            averageMood: moods.reduce(0, +) / Double(moods.count),
            sampleSize: steps.count
        )
    }

    // MARK: - Insights Generation

    /// Generates natural language insights based on data
    public func generateInsights(days: Int = 30) async throws -> [Insight] {
        var insights: [Insight] = []

        // Habit-mood correlations
        let correlations = try findMoodCorrelations(days: days)

        for corr in correlations.prefix(3) {
            if let c = corr.correlation, abs(c) > 0.3 {
                let direction = c > 0 ? "higher" : "lower"
                let habitName = corr.habit.name

                let insight = Insight(
                    type: .habitCorrelation,
                    title: "Pattern with \(habitName)",
                    description: "When you log \(habitName), your mood tends to be \(direction).",
                    strength: abs(c),
                    relatedHabit: corr.habit
                )
                insights.append(insight)
            }
        }

        // Day of week patterns
        let dayOfWeekSentiment = try sentimentByDayOfWeek(forLastDays: days)
        if let (bestDay, bestMood) = dayOfWeekSentiment.max(by: { $0.value < $1.value }),
           let (worstDay, worstMood) = dayOfWeekSentiment.min(by: { $0.value < $1.value }),
           bestMood - worstMood > 0.5 {

            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

            let insight = Insight(
                type: .temporalPattern,
                title: "Weekly Pattern",
                description: "Your mood tends to be highest on \(dayNames[bestDay]) and lowest on \(dayNames[worstDay]).",
                strength: (bestMood - worstMood) / 5.0, // Normalize to 0-1
                relatedHabit: nil
            )
            insights.append(insight)
        }

        // Sleep correlation
        if let sleepCorr = try await sleepMoodCorrelation(days: days),
           let c = sleepCorr.correlation, abs(c) > 0.3 {
            let direction = c > 0 ? "better" : "worse"

            let insight = Insight(
                type: .healthCorrelation,
                title: "Sleep & Mood",
                description: "More sleep is associated with \(direction) mood for you.",
                strength: abs(c),
                relatedHabit: nil
            )
            insights.append(insight)
        }

        // Steps correlation
        if let stepsCorr = try await stepsMoodCorrelation(days: days),
           let c = stepsCorr.correlation, abs(c) > 0.3 {
            let direction = c > 0 ? "better" : "worse"

            let insight = Insight(
                type: .healthCorrelation,
                title: "Activity & Mood",
                description: "More steps are associated with \(direction) mood for you.",
                strength: abs(c),
                relatedHabit: nil
            )
            insights.append(insight)
        }

        return insights.sorted { $0.strength > $1.strength }
    }

    // MARK: - Heatmap Data

    /// Generates heatmap data for habit-sentiment visualization
    public func generateHeatmapData(for habit: Habit, weeks: Int = 8) throws -> [[HeatmapCell]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the start of the week containing our start date
        let weeksAgo = calendar.date(byAdding: .weekOfYear, value: -weeks, to: today)!
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weeksAgo))!

        var grid: [[HeatmapCell]] = []

        // Build entries lookup for efficiency
        let entries = habit.entries.filter { $0.timestamp >= weekStart }
        var entriesByDay: [Date: [HabitEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            entriesByDay[day, default: []].append(entry)
        }

        // Generate grid (weeks x 7 days)
        var currentDate = weekStart
        var currentWeek: [HeatmapCell] = []

        while currentDate <= today {
            let dayEntries = entriesByDay[currentDate] ?? []
            let avgSentiment: Double? = dayEntries.isEmpty ? nil :
                Double(dayEntries.map(\.sentiment).reduce(0, +)) / Double(dayEntries.count)
            let totalValue: Double? = dayEntries.isEmpty ? nil :
                dayEntries.compactMap(\.value).reduce(0, +)

            let cell = HeatmapCell(
                date: currentDate,
                entryCount: dayEntries.count,
                averageSentiment: avgSentiment,
                totalValue: totalValue == 0 ? nil : totalValue
            )

            currentWeek.append(cell)

            if currentWeek.count == 7 {
                grid.append(currentWeek)
                currentWeek = []
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Add remaining partial week
        if !currentWeek.isEmpty {
            grid.append(currentWeek)
        }

        return grid
    }

    // MARK: - Habit Mood Comparison

    /// Computes average mood on days with a habit vs days without
    public func moodAverageWithAndWithout(habit: Habit, days: Int = 30) throws -> HabitMoodComparison {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!

        // Collect all mood data by day
        let allEntries = try fetchAllEntries(forLastDays: days)
        let sentimentRecords = try fetchAllSentimentRecords(forLastDays: days)

        var moodByDay: [Date: [Int]] = [:]
        for entry in allEntries {
            let day = calendar.startOfDay(for: entry.timestamp)
            moodByDay[day, default: []].append(entry.sentiment)
        }
        for record in sentimentRecords {
            let day = calendar.startOfDay(for: record.timestamp)
            moodByDay[day, default: []].append(record.sentiment)
        }

        // Identify days where the specific habit was logged
        let habitEntries = habit.entries.filter { $0.timestamp >= startDate }
        var habitDaySet: Set<Date> = []
        for entry in habitEntries {
            habitDaySet.insert(calendar.startOfDay(for: entry.timestamp))
        }

        // Partition mood averages
        var withHabitMoods: [Double] = []
        var withoutHabitMoods: [Double] = []

        for (day, sentiments) in moodByDay {
            guard !sentiments.isEmpty else { continue }
            let avg = Double(sentiments.reduce(0, +)) / Double(sentiments.count)
            if habitDaySet.contains(day) {
                withHabitMoods.append(avg)
            } else {
                withoutHabitMoods.append(avg)
            }
        }

        let avgWith = withHabitMoods.isEmpty ? nil : withHabitMoods.reduce(0, +) / Double(withHabitMoods.count)
        let avgWithout = withoutHabitMoods.isEmpty ? nil : withoutHabitMoods.reduce(0, +) / Double(withoutHabitMoods.count)

        return HabitMoodComparison(
            habit: habit,
            averageMoodWith: avgWith,
            averageMoodWithout: avgWithout,
            daysWithHabit: withHabitMoods.count,
            daysWithoutHabit: withoutHabitMoods.count,
            totalDays: moodByDay.count
        )
    }

    // MARK: - Private Helpers

    private func fetchAllHabits() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchAllEntries(forLastDays days: Int) throws -> [HabitEntry] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.timestamp >= startDate }
        )
        return try modelContext.fetch(descriptor).filter { $0.habit?.isArchived != true }
    }

    private func fetchAllSentimentRecords(forLastDays days: Int) throws -> [SentimentRecord] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<SentimentRecord>(
            predicate: #Predicate { $0.timestamp >= startDate }
        )
        return try modelContext.fetch(descriptor)
    }

    private func getMoodForDay(_ date: Date) throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let entriesDescriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        )
        let sentimentDescriptor = FetchDescriptor<SentimentRecord>(
            predicate: #Predicate { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        )

        let entries = try modelContext.fetch(entriesDescriptor).filter { $0.habit?.isArchived != true }
        let records = try modelContext.fetch(sentimentDescriptor)

        var allSentiments: [Int] = entries.map(\.sentiment) + records.map(\.sentiment)

        guard !allSentiments.isEmpty else { return nil }
        return Double(allSentiments.reduce(0, +)) / Double(allSentiments.count)
    }

    /// Calculates Pearson correlation coefficient
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

// MARK: - Supporting Types

public struct CorrelationResult: Identifiable {
    public let id = UUID()
    public let habit: Habit
    public let correlation: Double?
    public let sampleSize: Int
    public let periodDays: Int

    public var strengthDescription: String {
        guard let c = correlation else { return "Insufficient data" }
        let absC = abs(c)
        let direction = c > 0 ? "improves mood" : "lowers mood"
        if absC > 0.6 { return "Strong link · \(direction)" }
        if absC > 0.3 { return "Moderate link · \(direction)" }
        if absC > 0.1 { return "Mild link · \(direction)" }
        return "Weak link"
    }

    public var strengthLabel: String {
        guard let c = correlation else { return "Insufficient data" }
        let absC = abs(c)
        if absC > 0.6 { return "Strong link" }
        if absC > 0.3 { return "Moderate link" }
        if absC > 0.1 { return "Mild link" }
        return "Weak link"
    }

    /// Normalized strength for visual bar (0–1)
    public var normalizedStrength: Double {
        guard let c = correlation else { return 0 }
        return min(abs(c), 1.0)
    }

    /// Whether the correlation is positive
    public var isPositive: Bool {
        (correlation ?? 0) > 0
    }
}

public struct SleepMoodCorrelation {
    public let correlation: Double?
    public let averageSleepHours: Double
    public let averageMood: Double
    public let sampleSize: Int
}

public struct StepsMoodCorrelation {
    public let correlation: Double?
    public let averageSteps: Double
    public let averageMood: Double
    public let sampleSize: Int
}

public struct HabitMoodComparison {
    public let habit: Habit
    public let averageMoodWith: Double?
    public let averageMoodWithout: Double?
    public let daysWithHabit: Int
    public let daysWithoutHabit: Int
    public let totalDays: Int
}

public struct Insight: Identifiable {
    public let id = UUID()
    public let type: InsightType
    public let title: String
    public let description: String
    public let strength: Double // 0-1 indicating confidence/relevance
    public let relatedHabit: Habit?

    public enum InsightType {
        case habitCorrelation
        case temporalPattern
        case healthCorrelation
        case milestone
    }
}

public struct HeatmapCell: Identifiable {
    public let id = UUID()
    public let date: Date
    public let entryCount: Int
    public let averageSentiment: Double?
    public let totalValue: Double?

    public var hasData: Bool {
        entryCount > 0
    }

    public init(date: Date, entryCount: Int, averageSentiment: Double?, totalValue: Double? = nil) {
        self.date = date
        self.entryCount = entryCount
        self.averageSentiment = averageSentiment
        self.totalValue = totalValue
    }
}
