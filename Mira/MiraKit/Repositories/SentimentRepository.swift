import Combine
import Foundation
import SwiftData

/// Repository for standalone SentimentRecord CRUD operations
@MainActor
public final class SentimentRepository: ObservableObject {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// Creates a new standalone sentiment record
    @discardableResult
    public func create(
        sentiment: Int,
        note: String? = nil,
        contextTags: [String] = [],
        timestamp: Date = Date()
    ) throws -> SentimentRecord {
        let record = SentimentRecord(
            timestamp: timestamp,
            sentiment: sentiment,
            note: note,
            contextTags: contextTags,
            pendingSync: true
        )

        modelContext.insert(record)
        try modelContext.save()

        return record
    }

    // MARK: - Read

    /// Fetches all sentiment records, sorted by timestamp descending
    public func fetchAll() throws -> [SentimentRecord] {
        let descriptor = FetchDescriptor<SentimentRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches sentiment records within a date range
    public func fetch(from startDate: Date, to endDate: Date) throws -> [SentimentRecord] {
        let descriptor = FetchDescriptor<SentimentRecord>(
            predicate: #Predicate {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches today's sentiment records
    public func fetchToday() throws -> [SentimentRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try fetch(from: startOfDay, to: endOfDay)
    }

    /// Fetches the most recent sentiment record
    public func fetchMostRecent() throws -> SentimentRecord? {
        var descriptor = FetchDescriptor<SentimentRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Fetches a sentiment record by ID
    public func fetch(byId id: UUID) throws -> SentimentRecord? {
        let descriptor = FetchDescriptor<SentimentRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Fetches records with pending sync status
    public func fetchPendingSync() throws -> [SentimentRecord] {
        let descriptor = FetchDescriptor<SentimentRecord>(
            predicate: #Predicate { $0.pendingSync },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Update

    /// Updates a sentiment record
    public func update(
        _ record: SentimentRecord,
        sentiment: Int? = nil,
        note: String? = nil,
        contextTags: [String]? = nil
    ) throws {
        if let sentiment = sentiment {
            record.sentiment = min(max(sentiment, 1), 6)
        }
        if let note = note {
            record.note = note
        }
        if let contextTags = contextTags {
            record.contextTags = contextTags
        }

        record.pendingSync = true
        try modelContext.save()
    }

    /// Marks records as synced
    public func markSynced(_ records: [SentimentRecord]) throws {
        for record in records {
            record.pendingSync = false
        }
        try modelContext.save()
    }

    // MARK: - Delete

    /// Deletes a sentiment record
    public func delete(_ record: SentimentRecord) throws {
        modelContext.delete(record)
        try modelContext.save()
    }

    // MARK: - Statistics

    /// Returns the count of all sentiment records
    public func count() throws -> Int {
        let descriptor = FetchDescriptor<SentimentRecord>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Returns the average sentiment across all records
    public func averageSentiment() throws -> Double? {
        let records = try fetchAll()
        guard !records.isEmpty else { return nil }

        let total = records.reduce(0) { $0 + $1.sentiment }
        return Double(total) / Double(records.count)
    }

    /// Returns the average sentiment for a specific date range
    public func averageSentiment(from startDate: Date, to endDate: Date) throws -> Double? {
        let records = try fetch(from: startDate, to: endDate)
        guard !records.isEmpty else { return nil }

        let total = records.reduce(0) { $0 + $1.sentiment }
        return Double(total) / Double(records.count)
    }
}
