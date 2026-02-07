import Combine
import Foundation
import SwiftData

/// High-level service for habit operations
/// Coordinates between repositories and provides business logic
@MainActor
public final class HabitService: ObservableObject {
    private let modelContext: ModelContext

    private lazy var habitRepository: HabitRepository = {
        HabitRepository(modelContext: modelContext)
    }()

    private lazy var entryRepository: EntryRepository = {
        EntryRepository(modelContext: modelContext)
    }()

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Habit Management

    /// Creates a new habit with validation
    @discardableResult
    public func createHabit(
        name: String,
        icon: String = "circle.fill",
        colorHex: String = "#007AFF",
        trackingStyle: TrackingStyle = .occurrence,
        tags: [String] = [],
        isLocalOnly: Bool = false
    ) throws -> Habit {
        // Validate name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw HabitServiceError.invalidName
        }

        return try habitRepository.create(
            name: trimmedName,
            icon: icon,
            colorHex: colorHex,
            trackingStyle: trackingStyle,
            tags: tags,
            isLocalOnly: isLocalOnly
        )
    }

    /// Gets all active habits
    public func getActiveHabits() throws -> [Habit] {
        try habitRepository.fetchAll()
    }

    /// Gets habits that haven't been logged today
    public func getUnloggedHabitsToday() throws -> [Habit] {
        let habits = try habitRepository.fetchAll()
        return habits.filter { !$0.isLoggedToday }
    }

    /// Gets habits that have been logged today
    public func getLoggedHabitsToday() throws -> [Habit] {
        let habits = try habitRepository.fetchAll()
        return habits.filter { $0.isLoggedToday }
    }

    /// Archives a habit
    public func archiveHabit(_ habit: Habit) throws {
        try habitRepository.archive(habit)
    }

    /// Unarchives a habit
    public func unarchiveHabit(_ habit: Habit) throws {
        try habitRepository.unarchive(habit)
    }

    /// Permanently deletes a habit
    public func deleteHabit(_ habit: Habit) throws {
        try habitRepository.delete(habit)
    }

    // MARK: - Entry Logging

    /// Logs a new entry for a habit
    /// Sentiment is REQUIRED - core to Mira's philosophy
    @discardableResult
    public func logEntry(
        for habit: Habit,
        sentiment: Int,
        value: Double? = nil,
        note: String? = nil,
        contextTags: [String] = [],
        timestamp: Date = Date()
    ) throws -> HabitEntry {
        // Validate sentiment
        guard sentiment >= 1 && sentiment <= 6 else {
            throw HabitServiceError.invalidSentiment
        }

        // Validate value for tracking style
        if habit.trackingStyle != .occurrence && value == nil {
            throw HabitServiceError.missingValue
        }

        return try entryRepository.create(
            for: habit,
            sentiment: sentiment,
            value: value,
            note: note,
            contextTags: contextTags,
            timestamp: timestamp
        )
    }

    /// Gets all entries for a habit
    public func getEntries(for habit: Habit) throws -> [HabitEntry] {
        try entryRepository.fetchAll(for: habit)
    }

    /// Gets entries for a habit within a date range
    public func getEntries(for habit: Habit, from startDate: Date, to endDate: Date) throws -> [HabitEntry] {
        try entryRepository.fetch(for: habit, from: startDate, to: endDate)
    }

    /// Gets today's entries across all habits
    public func getTodayEntries() throws -> [HabitEntry] {
        try entryRepository.fetchTodayEntries()
    }

    /// Deletes an entry
    public func deleteEntry(_ entry: HabitEntry) throws {
        try entryRepository.delete(entry)
    }

    // MARK: - Statistics

    /// Gets a summary of today's activity
    public func getTodaySummary() throws -> DaySummary {
        let habits = try habitRepository.fetchAll()
        let todayEntries = try entryRepository.fetchTodayEntries()

        let loggedCount = habits.filter { $0.isLoggedToday }.count
        let totalHabits = habits.count

        let averageSentiment: Double? = {
            guard !todayEntries.isEmpty else { return nil }
            let total = todayEntries.reduce(0) { $0 + $1.sentiment }
            return Double(total) / Double(todayEntries.count)
        }()

        return DaySummary(
            totalHabits: totalHabits,
            loggedCount: loggedCount,
            entries: todayEntries,
            averageSentiment: averageSentiment
        )
    }

    /// Gets habit statistics for a given period
    public func getHabitStats(for habit: Habit, days: Int = 30) throws -> HabitStats {
        let entries = habit.entries(forLastDays: days)

        let totalEntries = entries.count
        let averageSentiment: Double? = {
            guard !entries.isEmpty else { return nil }
            let total = entries.reduce(0) { $0 + $1.sentiment }
            return Double(total) / Double(entries.count)
        }()

        // Count entries per day
        let calendar = Calendar.current
        var entriesPerDay: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            entriesPerDay[day, default: 0] += 1
        }

        // Calculate average entries per day (only days with entries)
        let averageEntriesPerDay = entriesPerDay.isEmpty ? 0.0 : Double(totalEntries) / Double(entriesPerDay.count)

        // Sum all entry values (for quantity/duration habits)
        let totalValue: Double? = {
            let sum = entries.compactMap(\.value).reduce(0, +)
            return sum > 0 ? sum : nil
        }()

        return HabitStats(
            habit: habit,
            periodDays: days,
            totalEntries: totalEntries,
            averageSentiment: averageSentiment,
            entriesPerDay: entriesPerDay,
            averageEntriesPerDay: averageEntriesPerDay,
            totalValue: totalValue
        )
    }
}

// MARK: - Supporting Types

public enum HabitServiceError: LocalizedError {
    case invalidName
    case invalidSentiment
    case missingValue

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Habit name cannot be empty"
        case .invalidSentiment:
            return "Sentiment must be between 1 and 6"
        case .missingValue:
            return "A value is required for this tracking style"
        }
    }
}

public struct DaySummary {
    public let totalHabits: Int
    public let loggedCount: Int
    public let entries: [HabitEntry]
    public let averageSentiment: Double?

    public var completionRate: Double {
        guard totalHabits > 0 else { return 0 }
        return Double(loggedCount) / Double(totalHabits)
    }
}

public struct HabitStats {
    public let habit: Habit
    public let periodDays: Int
    public let totalEntries: Int
    public let averageSentiment: Double?
    public let entriesPerDay: [Date: Int]
    public let averageEntriesPerDay: Double
    public let totalValue: Double?
}
