import Combine
import Foundation
import SwiftData

/// Repository for HabitEntry CRUD operations
@MainActor
public final class EntryRepository: ObservableObject {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// Creates a new entry for a habit
    /// Sentiment is REQUIRED - this is core to Mira's philosophy
    @discardableResult
    public func create(
        for habit: Habit,
        sentiment: Int,
        value: Double? = nil,
        note: String? = nil,
        contextTags: [String] = [],
        timestamp: Date = Date()
    ) throws -> HabitEntry {
        let entry = HabitEntry(
            habit: habit,
            timestamp: timestamp,
            sentiment: sentiment,
            value: value,
            note: note,
            contextTags: contextTags,
            pendingSync: !habit.isLocalOnly
        )

        modelContext.insert(entry)
        habit.entries.append(entry)
        habit.updatedAt = Date()
        try modelContext.save()

        return entry
    }

    // MARK: - Read

    /// Fetches all entries for a habit, sorted by timestamp descending
    public func fetchAll(for habit: Habit) throws -> [HabitEntry] {
        let habitId = habit.id
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.habit?.id == habitId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches entries for a habit within a date range
    public func fetch(for habit: Habit, from startDate: Date, to endDate: Date) throws -> [HabitEntry] {
        let habitId = habit.id
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate {
                $0.habit?.id == habitId &&
                $0.timestamp >= startDate &&
                $0.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches all entries for today across all habits
    public func fetchTodayEntries() throws -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).filter { $0.habit?.isArchived != true }
    }

    /// Fetches entries with pending sync status
    public func fetchPendingSync() throws -> [HabitEntry] {
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.pendingSync },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches the most recent entry for a habit
    public func fetchMostRecent(for habit: Habit) throws -> HabitEntry? {
        let habitId = habit.id
        var descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.habit?.id == habitId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetches entries by ID
    public func fetch(byId id: UUID) throws -> HabitEntry? {
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Update

    /// Updates an entry
    public func update(
        _ entry: HabitEntry,
        sentiment: Int? = nil,
        value: Double? = nil,
        note: String? = nil,
        contextTags: [String]? = nil
    ) throws {
        if let sentiment = sentiment {
            entry.sentiment = min(max(sentiment, 1), 6)
        }
        if let value = value {
            entry.value = value
        }
        if let note = note {
            entry.note = note
        }
        if let contextTags = contextTags {
            entry.contextTags = contextTags
        }

        // Mark for re-sync if not local-only
        if let habit = entry.habit, !habit.isLocalOnly {
            entry.pendingSync = true
        }

        try modelContext.save()
    }

    /// Marks entries as synced
    public func markSynced(_ entries: [HabitEntry]) throws {
        for entry in entries {
            entry.pendingSync = false
        }
        try modelContext.save()
    }

    // MARK: - Delete

    /// Deletes an entry
    public func delete(_ entry: HabitEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }

    /// Deletes all entries for a habit
    public func deleteAll(for habit: Habit) throws {
        let entries = try fetchAll(for: habit)
        for entry in entries {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }

    // MARK: - Statistics

    /// Returns the count of entries for a habit
    public func count(for habit: Habit) throws -> Int {
        let habitId = habit.id
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { $0.habit?.id == habitId }
        )
        return try modelContext.fetchCount(descriptor)
    }

    /// Returns the average sentiment for a habit
    public func averageSentiment(for habit: Habit) throws -> Double? {
        let entries = try fetchAll(for: habit)
        guard !entries.isEmpty else { return nil }

        let total = entries.reduce(0) { $0 + $1.sentiment }
        return Double(total) / Double(entries.count)
    }
}
