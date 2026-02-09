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

    /// Calculates correlation between a habit's presence and mood using point-biserial correlation.
    /// For each day with mood data, correlates habit logged (1) vs not logged (0) with average mood.
    /// A positive value means logging the habit is associated with higher mood; negative with lower mood.
    public func habitMoodCorrelation(for habit: Habit, days: Int = 30) throws -> CorrelationResult {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!

        // Identify days where this habit was logged
        let habitEntries = habit.allEntries.filter { $0.timestamp >= startDate }
        var habitDaySet: Set<Date> = []
        for entry in habitEntries {
            habitDaySet.insert(calendar.startOfDay(for: entry.timestamp))
        }

        // Collect overall mood by day (all entries + sentiment records)
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

        // Point-biserial: for each day with mood data, x = habit present (1/0), y = avg mood
        var habitPresence: [Double] = []
        var dayMoodAvgs: [Double] = []
        var moodsOnHabitDays: [Double] = []

        for (day, sentiments) in moodByDay {
            guard !sentiments.isEmpty else { continue }
            let avg = Double(sentiments.reduce(0, +)) / Double(sentiments.count)
            let logged = habitDaySet.contains(day)
            habitPresence.append(logged ? 1.0 : 0.0)
            dayMoodAvgs.append(avg)
            if logged {
                moodsOnHabitDays.append(avg)
            }
        }

        // Pearson on binary x gives point-biserial correlation
        let correlation = pearsonCorrelation(x: habitPresence, y: dayMoodAvgs)

        let avgMoodWhenLogged: Double? = moodsOnHabitDays.isEmpty ? nil :
            moodsOnHabitDays.reduce(0, +) / Double(moodsOnHabitDays.count)

        return CorrelationResult(
            habit: habit,
            correlation: correlation,
            sampleSize: habitDaySet.count,
            periodDays: days,
            averageMoodWhenLogged: avgMoodWhenLogged
        )
    }

    /// Finds habits most correlated with high/low mood
    public func findMoodCorrelations(days: Int = 30) throws -> [CorrelationResult] {
        let habits = try fetchAllHabits()
        var results: [CorrelationResult] = []

        for habit in habits {
            let result = try habitMoodCorrelation(for: habit, days: days)
            if result.sampleSize >= 1 {
                results.append(result)
            }
        }

        // Sort: strong correlations first, then by sample size for early data
        return results.sorted {
            let a = abs($0.correlation ?? 0)
            let b = abs($1.correlation ?? 0)
            if a != b { return a > b }
            return $0.sampleSize > $1.sampleSize
        }
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

        guard sleepScores.count >= 2 else { return nil }

        let correlation = pearsonCorrelation(x: sleepScores, y: moodScores)

        return SleepMoodCorrelation(
            correlation: correlation,
            averageSleepHours: sleepScores.reduce(0, +) / Double(sleepScores.count),
            averageMood: moodScores.reduce(0, +) / Double(moodScores.count),
            sampleSize: sleepScores.count
        )
    }

    /// Correlates resting heart rate with mood
    public func restingHeartRateMoodCorrelation(days: Int = 30) async throws -> RestingHeartRateMoodCorrelation? {
        guard healthKitManager.isAvailable else { return nil }

        let calendar = Calendar.current
        var hrValues: [Double] = []
        var moodValues: [Double] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            if let restingHR = try? await healthKitManager.getRestingHeartRate(for: date),
               let dayMood = try getMoodForDay(date) {
                hrValues.append(restingHR)
                moodValues.append(dayMood)
            }
        }

        guard hrValues.count >= 2 else { return nil }

        let correlation = pearsonCorrelation(x: hrValues, y: moodValues)

        return RestingHeartRateMoodCorrelation(
            correlation: correlation,
            averageHeartRate: hrValues.reduce(0, +) / Double(hrValues.count),
            averageMood: moodValues.reduce(0, +) / Double(moodValues.count),
            sampleSize: hrValues.count
        )
    }

    /// Correlates heart rate variability with mood
    public func hrvMoodCorrelation(days: Int = 30) async throws -> HRVMoodCorrelation? {
        guard healthKitManager.isAvailable else { return nil }

        let calendar = Calendar.current
        var hrvValues: [Double] = []
        var moodValues: [Double] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            if let hrv = try? await healthKitManager.getAverageHRV(for: date),
               let dayMood = try getMoodForDay(date) {
                hrvValues.append(hrv)
                moodValues.append(dayMood)
            }
        }

        guard hrvValues.count >= 2 else { return nil }

        let correlation = pearsonCorrelation(x: hrvValues, y: moodValues)

        return HRVMoodCorrelation(
            correlation: correlation,
            averageHRV: hrvValues.reduce(0, +) / Double(hrvValues.count),
            averageMood: moodValues.reduce(0, +) / Double(moodValues.count),
            sampleSize: hrvValues.count
        )
    }

    /// Fetches all available health-mood correlations
    public func allHealthCorrelations(days: Int = 30) async throws -> [HealthCorrelation] {
        var results: [HealthCorrelation] = []

        if let sleep = try await sleepMoodCorrelation(days: days) {
            results.append(HealthCorrelation(
                metric: .sleep,
                correlation: sleep.correlation,
                averageMetricValue: sleep.averageSleepHours,
                averageMood: sleep.averageMood,
                sampleSize: sleep.sampleSize
            ))
        }

        if let steps = try await stepsMoodCorrelation(days: days) {
            results.append(HealthCorrelation(
                metric: .steps,
                correlation: steps.correlation,
                averageMetricValue: steps.averageSteps,
                averageMood: steps.averageMood,
                sampleSize: steps.sampleSize
            ))
        }

        if let hr = try await restingHeartRateMoodCorrelation(days: days) {
            results.append(HealthCorrelation(
                metric: .restingHeartRate,
                correlation: hr.correlation,
                averageMetricValue: hr.averageHeartRate,
                averageMood: hr.averageMood,
                sampleSize: hr.sampleSize
            ))
        }

        if let hrv = try await hrvMoodCorrelation(days: days) {
            results.append(HealthCorrelation(
                metric: .hrv,
                correlation: hrv.correlation,
                averageMetricValue: hrv.averageHRV,
                averageMood: hrv.averageMood,
                sampleSize: hrv.sampleSize
            ))
        }

        return results.sorted { abs($0.correlation ?? 0) > abs($1.correlation ?? 0) }
    }

    /// Correlates step count with mood
    public func stepsMoodCorrelation(days: Int = 30) async throws -> StepsMoodCorrelation? {
        guard healthKitManager.isAvailable else { return nil }

        let stepsByDay = try await healthKitManager.getSteps(forLastDays: days)

        var steps: [Double] = []
        var moods: [Double] = []

        for (date, stepCount) in stepsByDay {
            // Skip days with 0 steps (likely no watch data, not a real 0)
            guard stepCount > 0 else { continue }
            if let dayMood = try getMoodForDay(date) {
                steps.append(Double(stepCount))
                moods.append(dayMood)
            }
        }

        guard steps.count >= 2 else { return nil }

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

        let allEntries = try fetchAllEntries(forLastDays: days)
        let sentimentRecords = try fetchAllSentimentRecords(forLastDays: days)
        let habits = try fetchAllHabits()
        let totalLogs = allEntries.count + sentimentRecords.count
        let allSentiments = allEntries.map(\.sentiment) + sentimentRecords.map(\.sentiment)

        // === Correlation-based insights (lowered threshold from 0.3 → 0.15) ===
        let correlations = try findMoodCorrelations(days: days)

        for corr in correlations.prefix(3) {
            if let c = corr.correlation, abs(c) > 0.15 {
                let direction = c > 0 ? "higher" : "lower"
                let habitName = corr.habit.name

                insights.append(Insight(
                    type: .habitCorrelation,
                    title: "Pattern with \(habitName)",
                    description: "When you log \(habitName), your mood tends to be \(direction).",
                    strength: abs(c),
                    relatedHabit: corr.habit
                ))
            }
        }

        // === Day of week pattern (lowered threshold from 0.5 → 0.3) ===
        let dayOfWeekSentiment = try sentimentByDayOfWeek(forLastDays: days)
        if let (bestDay, bestMood) = dayOfWeekSentiment.max(by: { $0.value < $1.value }),
           let (worstDay, worstMood) = dayOfWeekSentiment.min(by: { $0.value < $1.value }),
           bestMood - worstMood > 0.3 {

            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

            insights.append(Insight(
                type: .temporalPattern,
                title: "Weekly Pattern",
                description: "Your mood tends to be highest on \(dayNames[bestDay]) and lowest on \(dayNames[worstDay]).",
                strength: min((bestMood - worstMood) / 5.0, 1.0),
                relatedHabit: nil
            ))
        }

        // === Logging frequency ↔ mood (easy to achieve with a few entries across days) ===
        let calendar = Calendar.current
        var logCountByDay: [Date: Int] = [:]
        var moodByDayMap: [Date: [Int]] = [:]
        for entry in allEntries {
            let day = calendar.startOfDay(for: entry.timestamp)
            logCountByDay[day, default: 0] += 1
            moodByDayMap[day, default: []].append(entry.sentiment)
        }
        for record in sentimentRecords {
            let day = calendar.startOfDay(for: record.timestamp)
            moodByDayMap[day, default: []].append(record.sentiment)
        }

        var logCounts: [Double] = []
        var dayMoods: [Double] = []
        for (day, count) in logCountByDay {
            if let moods = moodByDayMap[day], !moods.isEmpty {
                logCounts.append(Double(count))
                dayMoods.append(Double(moods.reduce(0, +)) / Double(moods.count))
            }
        }
        if logCounts.count >= 3,
           let c = pearsonCorrelation(x: logCounts, y: dayMoods), abs(c) > 0.15 {
            let direction = c > 0 ? "higher" : "lower"
            insights.append(Insight(
                type: .habitCorrelation,
                title: "Tracking & Mood",
                description: "On days you log more, your mood tends to be \(direction).",
                strength: abs(c) * 0.8,
                relatedHabit: nil
            ))
        }

        // === Health correlations (lowered threshold from 0.3 → 0.15) ===

        if let sleepCorr = try await sleepMoodCorrelation(days: days),
           let c = sleepCorr.correlation, abs(c) > 0.15 {
            let direction = c > 0 ? "better" : "worse"
            insights.append(Insight(
                type: .healthCorrelation,
                title: "Sleep & Mood",
                description: "More sleep is associated with \(direction) mood for you.",
                strength: abs(c),
                relatedHabit: nil
            ))
        }

        if let stepsCorr = try await stepsMoodCorrelation(days: days),
           let c = stepsCorr.correlation, abs(c) > 0.15 {
            let direction = c > 0 ? "better" : "worse"
            insights.append(Insight(
                type: .healthCorrelation,
                title: "Activity & Mood",
                description: "More steps are associated with \(direction) mood for you.",
                strength: abs(c),
                relatedHabit: nil
            ))
        }

        if let hrCorr = try await restingHeartRateMoodCorrelation(days: days),
           let c = hrCorr.correlation, abs(c) > 0.15 {
            let direction = c > 0 ? "higher" : "lower"
            insights.append(Insight(
                type: .healthCorrelation,
                title: "Heart Rate & Mood",
                description: "A higher resting heart rate is associated with \(direction) mood for you.",
                strength: abs(c),
                relatedHabit: nil
            ))
        }

        if let hrvCorr = try await hrvMoodCorrelation(days: days),
           let c = hrvCorr.correlation, abs(c) > 0.15 {
            let direction = c > 0 ? "better" : "worse"
            insights.append(Insight(
                type: .healthCorrelation,
                title: "HRV & Mood",
                description: "Higher heart rate variability is associated with \(direction) mood for you.",
                strength: abs(c),
                relatedHabit: nil
            ))
        }

        // === Simple observations (work with very little data) ===

        // Mood snapshot
        if !allSentiments.isEmpty {
            let avg = Double(allSentiments.reduce(0, +)) / Double(allSentiments.count)
            let emoji = sentimentEmojiFor(Int(avg.rounded()))
            insights.append(Insight(
                type: .temporalPattern,
                title: "Mood Snapshot",
                description: "Your average mood over the last \(days) days is \(String(format: "%.1f", avg)) \(emoji).",
                strength: 0.15,
                relatedHabit: nil
            ))
        }

        // Most-tracked habit
        if let mostLogged = habits.max(by: { $0.entries(forLastDays: days).count < $1.entries(forLastDays: days).count }),
           mostLogged.entries(forLastDays: days).count >= 2 {
            let count = mostLogged.entries(forLastDays: days).count
            insights.append(Insight(
                type: .habitCorrelation,
                title: "Most Tracked",
                description: "You've logged \(mostLogged.name) \(count) times — it's your most tracked habit.",
                strength: 0.15,
                relatedHabit: mostLogged
            ))
        }

        // === Milestones ===

        if totalLogs > 0 && totalLogs <= 5 {
            insights.append(Insight(
                type: .milestone,
                title: "You've Started",
                description: "You've logged \(totalLogs) \(totalLogs == 1 ? "entry" : "entries"). Every data point helps build your picture.",
                strength: 0.2,
                relatedHabit: nil
            ))
        } else if totalLogs >= 10 && totalLogs < 25 {
            insights.append(Insight(
                type: .milestone,
                title: "Building Momentum",
                description: "\(totalLogs) entries so far. Patterns are starting to take shape.",
                strength: 0.25,
                relatedHabit: nil
            ))
        } else if totalLogs >= 25 {
            insights.append(Insight(
                type: .milestone,
                title: "Rich Dataset",
                description: "\(totalLogs) entries give Mira a solid foundation for finding patterns.",
                strength: 0.3,
                relatedHabit: nil
            ))
        }

        // === Wisdom insights (shown for sparse data, rotating daily) ===

        if totalLogs < 15 {
            let wisdomPool: [(title: String, description: String)] = [
                ("Observe, Don't Judge",
                 "There are no \"good\" or \"bad\" habits here — just patterns waiting to be noticed."),
                ("Every Entry Counts",
                 "Even logging a rough day is valuable. That data point matters just as much."),
                ("Patterns Take Time",
                 "The more you log, the more correlations emerge. There's no rush."),
                ("You Define Progress",
                 "Mira doesn't set goals for you. Understanding yourself is the goal."),
                ("No Neutral Option",
                 "The 1–6 scale has no middle — because honest reflection starts with a choice."),
                ("Data, Not Pressure",
                 "Missed a day? That's fine. When you come back, your data is here waiting."),
            ]
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
            let index = dayOfYear % wisdomPool.count
            let wisdom = wisdomPool[index]
            insights.append(Insight(
                type: .milestone,
                title: wisdom.title,
                description: wisdom.description,
                strength: 0.1,
                relatedHabit: nil
            ))
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
        let entries = habit.allEntries.filter { $0.timestamp >= weekStart }
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
        let habitEntries = habit.allEntries.filter { $0.timestamp >= startDate }
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
    public let averageMoodWhenLogged: Double?

    public var strengthDescription: String {
        guard let c = correlation else {
            if let avg = averageMoodWhenLogged {
                let emoji = sentimentEmojiFor(Int(avg.rounded()))
                return "Avg mood \(String(format: "%.1f", avg)) \(emoji) · keep logging"
            }
            return "Keep logging to see patterns"
        }
        let absC = abs(c)
        let direction = c > 0 ? "improves mood" : "lowers mood"
        if absC > 0.6 { return "Strong link · \(direction)" }
        if absC > 0.3 { return "Moderate link · \(direction)" }
        if absC > 0.1 { return "Mild link · \(direction)" }
        return "Weak link · \(direction)"
    }

    public var strengthLabel: String {
        guard let c = correlation else {
            if averageMoodWhenLogged != nil {
                return "Early data"
            }
            return "Not enough data"
        }
        let absC = abs(c)
        if absC > 0.6 { return "Strong link" }
        if absC > 0.3 { return "Moderate link" }
        if absC > 0.1 { return "Mild link" }
        return "Weak link"
    }

    /// Normalized strength for visual bar (0–1)
    public var normalizedStrength: Double {
        if let c = correlation { return min(abs(c), 1.0) }
        // For early data, show mood deviation from neutral as progress
        if let avg = averageMoodWhenLogged {
            return min(abs(avg - 3.5) / 2.5, 1.0)
        }
        return 0
    }

    /// Whether the correlation is positive
    public var isPositive: Bool {
        if let c = correlation { return c > 0 }
        if let avg = averageMoodWhenLogged { return avg > 3.5 }
        return true
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

public struct RestingHeartRateMoodCorrelation {
    public let correlation: Double?
    public let averageHeartRate: Double
    public let averageMood: Double
    public let sampleSize: Int
}

public struct HRVMoodCorrelation {
    public let correlation: Double?
    public let averageHRV: Double
    public let averageMood: Double
    public let sampleSize: Int
}

public struct HealthCorrelation: Identifiable {
    public let id = UUID()
    public let metric: HealthMetric
    public let correlation: Double?
    public let averageMetricValue: Double
    public let averageMood: Double
    public let sampleSize: Int

    public var isPositive: Bool {
        (correlation ?? 0) > 0
    }

    public var normalizedStrength: Double {
        if let c = correlation { return min(abs(c), 1.0) }
        // For early data, show mood deviation from neutral
        return min(abs(averageMood - 3.5) / 2.5, 1.0)
    }

    public var strengthDescription: String {
        guard let c = correlation else {
            let emoji = sentimentEmojiFor(Int(averageMood.rounded()))
            return "Avg mood \(String(format: "%.1f", averageMood)) \(emoji) · tracking"
        }
        let absC = abs(c)
        let verb = metric.moodVerb(positive: c > 0)
        if absC > 0.6 { return "Strong link · \(verb)" }
        if absC > 0.3 { return "Moderate link · \(verb)" }
        if absC > 0.1 { return "Mild link · \(verb)" }
        return "Weak link · \(verb)"
    }

    public var strengthLabel: String {
        guard let c = correlation else { return "Early data" }
        let absC = abs(c)
        if absC > 0.6 { return "Strong link" }
        if absC > 0.3 { return "Moderate link" }
        if absC > 0.1 { return "Mild link" }
        return "Weak link"
    }

    public var formattedValue: String {
        metric.formatValue(averageMetricValue)
    }

    public enum HealthMetric: String, CaseIterable {
        case sleep
        case steps
        case restingHeartRate
        case hrv

        public var name: String {
            switch self {
            case .sleep: return "Sleep"
            case .steps: return "Steps"
            case .restingHeartRate: return "Resting Heart Rate"
            case .hrv: return "Heart Rate Variability"
            }
        }

        public var shortName: String {
            switch self {
            case .sleep: return "Sleep"
            case .steps: return "Steps"
            case .restingHeartRate: return "Resting HR"
            case .hrv: return "HRV"
            }
        }

        public var icon: String {
            switch self {
            case .sleep: return "bed.double.fill"
            case .steps: return "figure.walk"
            case .restingHeartRate: return "heart.fill"
            case .hrv: return "waveform.path.ecg"
            }
        }

        public var unit: String {
            switch self {
            case .sleep: return "hrs"
            case .steps: return "steps"
            case .restingHeartRate: return "bpm"
            case .hrv: return "ms"
            }
        }

        public func formatValue(_ value: Double) -> String {
            switch self {
            case .sleep: return String(format: "%.1f %@", value, unit)
            case .steps: return "\(Int(value).formatted()) \(unit)"
            case .restingHeartRate: return "\(Int(value)) \(unit)"
            case .hrv: return "\(Int(value)) \(unit)"
            }
        }

        public func moodVerb(positive: Bool) -> String {
            positive ? "improves mood" : "lowers mood"
        }
    }
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
