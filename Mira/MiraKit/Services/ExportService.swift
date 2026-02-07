import Combine
import Foundation
import SwiftData

/// Service for exporting and importing user data
/// Supports JSON format for manual backup/restore
@MainActor
public final class ExportService: ObservableObject {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export

    /// Exports all user data to JSON
    public func exportAllData() throws -> Data {
        let habits = try fetchAllHabits()
        let sentimentRecords = try fetchAllSentimentRecords()
        let preferences = try fetchPreferences()

        let exportData = ExportData(
            exportDate: Date(),
            version: "1.0",
            habits: habits.map { ExportHabit(from: $0) },
            sentimentRecords: sentimentRecords.map { ExportSentimentRecord(from: $0) },
            preferences: preferences.map { ExportPreferences(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }

    /// Exports data as a shareable file URL
    public func exportToFile() throws -> URL {
        let data = try exportAllData()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let filename = "mira_backup_\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        try data.write(to: tempURL)
        return tempURL
    }

    // MARK: - Import

    /// Imports data from JSON, optionally merging or replacing existing data
    public func importData(from data: Data, mode: ImportMode = .merge) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importData = try decoder.decode(ExportData.self, from: data)

        var habitsImported = 0
        var entriesImported = 0
        var sentimentRecordsImported = 0
        var skipped = 0

        // Clear existing data if replacing
        if mode == .replace {
            try clearAllData()
        }

        // Import habits and their entries
        for exportHabit in importData.habits {
            // Check for existing habit with same ID
            if mode == .merge {
                if let existing = try fetchHabit(byId: exportHabit.id) {
                    // Skip if already exists in merge mode
                    skipped += 1
                    continue
                }
            }

            let habit = Habit(
                id: exportHabit.id,
                name: exportHabit.name,
                icon: exportHabit.icon,
                colorHex: exportHabit.colorHex,
                trackingStyle: TrackingStyle(rawValue: exportHabit.trackingStyle) ?? .occurrence,
                tags: exportHabit.tags,
                isLocalOnly: exportHabit.isLocalOnly,
                isArchived: exportHabit.isArchived,
                displayOrder: exportHabit.displayOrder
            )
            habit.createdAt = exportHabit.createdAt
            habit.updatedAt = exportHabit.updatedAt

            modelContext.insert(habit)
            habitsImported += 1

            // Import entries for this habit
            for exportEntry in exportHabit.entries {
                let entry = HabitEntry(
                    id: exportEntry.id,
                    habit: habit,
                    timestamp: exportEntry.timestamp,
                    sentiment: exportEntry.sentiment,
                    value: exportEntry.value,
                    note: exportEntry.note,
                    contextTags: exportEntry.contextTags,
                    pendingSync: false
                )
                entry.createdAt = exportEntry.createdAt

                modelContext.insert(entry)
                entriesImported += 1
            }
        }

        // Import sentiment records
        for exportRecord in importData.sentimentRecords {
            if mode == .merge {
                if let _ = try fetchSentimentRecord(byId: exportRecord.id) {
                    skipped += 1
                    continue
                }
            }

            let record = SentimentRecord(
                id: exportRecord.id,
                timestamp: exportRecord.timestamp,
                sentiment: exportRecord.sentiment,
                note: exportRecord.note,
                contextTags: exportRecord.contextTags,
                pendingSync: false
            )

            modelContext.insert(record)
            sentimentRecordsImported += 1
        }

        // Import preferences (only if replacing or no preferences exist)
        if let exportPrefs = importData.preferences {
            if mode == .replace {
                try updatePreferences(from: exportPrefs)
            }
        }

        try modelContext.save()

        return ImportResult(
            habitsImported: habitsImported,
            entriesImported: entriesImported,
            sentimentRecordsImported: sentimentRecordsImported,
            skipped: skipped,
            version: importData.version
        )
    }

    /// Imports data from a file URL
    public func importFromFile(_ url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        return try importData(from: data, mode: .merge)
    }

    // MARK: - Private Helpers

    private func fetchAllHabits() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>()
        return try modelContext.fetch(descriptor)
    }

    private func fetchAllSentimentRecords() throws -> [SentimentRecord] {
        let descriptor = FetchDescriptor<SentimentRecord>()
        return try modelContext.fetch(descriptor)
    }

    private func fetchPreferences() throws -> UserPreferences? {
        let descriptor = FetchDescriptor<UserPreferences>()
        return try modelContext.fetch(descriptor).first
    }

    private func fetchHabit(byId id: UUID) throws -> Habit? {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchSentimentRecord(byId id: UUID) throws -> SentimentRecord? {
        let descriptor = FetchDescriptor<SentimentRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func clearAllData() throws {
        let habits = try fetchAllHabits()
        for habit in habits {
            modelContext.delete(habit)
        }

        let records = try fetchAllSentimentRecords()
        for record in records {
            modelContext.delete(record)
        }

        try modelContext.save()
    }

    private func updatePreferences(from exported: ExportPreferences) throws {
        let descriptor = FetchDescriptor<UserPreferences>()
        let existing = try modelContext.fetch(descriptor).first

        let prefs = existing ?? UserPreferences()
        if existing == nil {
            modelContext.insert(prefs)
        }

        prefs.disableHaptics = exported.disableHaptics
        prefs.reduceMotion = exported.reduceMotion
        prefs.highContrast = exported.highContrast
        prefs.useDyslexiaFont = exported.useDyslexiaFont
        prefs.requireAuthentication = exported.requireAuthentication
        prefs.hideInAppSwitcher = exported.hideInAppSwitcher
        prefs.healthKitEnabled = exported.healthKitEnabled
        prefs.notificationsEnabled = exported.notificationsEnabled
        prefs.defaultReminderHour = exported.defaultReminderHour
        prefs.defaultReminderMinute = exported.defaultReminderMinute
        prefs.showCompletedOnDashboard = exported.showCompletedOnDashboard
    }
}

// MARK: - Export Data Types

public struct ExportData: Codable {
    public let exportDate: Date
    public let version: String
    public let habits: [ExportHabit]
    public let sentimentRecords: [ExportSentimentRecord]
    public let preferences: ExportPreferences?
}

public struct ExportHabit: Codable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let colorHex: String
    public let trackingStyle: String
    public let tags: [String]
    public let isLocalOnly: Bool
    public let isArchived: Bool
    public let displayOrder: Int
    public let createdAt: Date
    public let updatedAt: Date
    public let entries: [ExportEntry]

    init(from habit: Habit) {
        self.id = habit.id
        self.name = habit.name
        self.icon = habit.icon
        self.colorHex = habit.colorHex
        self.trackingStyle = habit.trackingStyleRaw
        self.tags = habit.tags
        self.isLocalOnly = habit.isLocalOnly
        self.isArchived = habit.isArchived
        self.displayOrder = habit.displayOrder
        self.createdAt = habit.createdAt
        self.updatedAt = habit.updatedAt
        self.entries = habit.entries.map { ExportEntry(from: $0) }
    }
}

public struct ExportEntry: Codable {
    public let id: UUID
    public let timestamp: Date
    public let sentiment: Int
    public let value: Double?
    public let note: String?
    public let contextTags: [String]
    public let createdAt: Date

    init(from entry: HabitEntry) {
        self.id = entry.id
        self.timestamp = entry.timestamp
        self.sentiment = entry.sentiment
        self.value = entry.value
        self.note = entry.note
        self.contextTags = entry.contextTags
        self.createdAt = entry.createdAt
    }
}

public struct ExportSentimentRecord: Codable {
    public let id: UUID
    public let timestamp: Date
    public let sentiment: Int
    public let note: String?
    public let contextTags: [String]

    init(from record: SentimentRecord) {
        self.id = record.id
        self.timestamp = record.timestamp
        self.sentiment = record.sentiment
        self.note = record.note
        self.contextTags = record.contextTags
    }
}

public struct ExportPreferences: Codable {
    public let disableHaptics: Bool
    public let reduceMotion: Bool
    public let highContrast: Bool
    public let useDyslexiaFont: Bool
    public let requireAuthentication: Bool
    public let hideInAppSwitcher: Bool
    public let healthKitEnabled: Bool
    public let notificationsEnabled: Bool
    public let defaultReminderHour: Int
    public let defaultReminderMinute: Int
    public let showCompletedOnDashboard: Bool

    init(from prefs: UserPreferences) {
        self.disableHaptics = prefs.disableHaptics
        self.reduceMotion = prefs.reduceMotion
        self.highContrast = prefs.highContrast
        self.useDyslexiaFont = prefs.useDyslexiaFont
        self.requireAuthentication = prefs.requireAuthentication
        self.hideInAppSwitcher = prefs.hideInAppSwitcher
        self.healthKitEnabled = prefs.healthKitEnabled
        self.notificationsEnabled = prefs.notificationsEnabled
        self.defaultReminderHour = prefs.defaultReminderHour
        self.defaultReminderMinute = prefs.defaultReminderMinute
        self.showCompletedOnDashboard = prefs.showCompletedOnDashboard
    }
}

// MARK: - Import Types

public enum ImportMode {
    case merge   // Keep existing, add new
    case replace // Clear existing, import all
}

public struct ImportResult {
    public let habitsImported: Int
    public let entriesImported: Int
    public let sentimentRecordsImported: Int
    public let skipped: Int
    public let version: String

    public var totalImported: Int {
        habitsImported + entriesImported + sentimentRecordsImported
    }
}
