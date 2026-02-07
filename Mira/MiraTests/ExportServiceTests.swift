import Testing
import Foundation
@testable import MiraKit

@Suite("Export Data Structure Tests")
struct ExportDataTests {

    @Test("ExportData encoding")
    func testExportDataEncoding() throws {
        let exportData = ExportData(
            exportDate: Date(),
            version: "1.0",
            habits: [],
            sentimentRecords: [],
            preferences: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)
        #expect(data.count > 0)

        // Verify it can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)

        #expect(decoded.version == "1.0")
        #expect(decoded.habits.isEmpty)
    }

    @Test("ExportHabit encoding")
    func testExportHabitEncoding() throws {
        let habit = Habit(
            name: "Test",
            icon: "star.fill",
            colorHex: "#FF0000",
            trackingStyle: .duration
        )
        let exportHabit = ExportHabit(from: habit)

        #expect(exportHabit.name == "Test")
        #expect(exportHabit.icon == "star.fill")
        #expect(exportHabit.colorHex == "#FF0000")
        #expect(exportHabit.trackingStyle == "duration")

        let encoder = JSONEncoder()
        let data = try encoder.encode(exportHabit)
        #expect(data.count > 0)
    }

    @Test("ExportEntry encoding")
    func testExportEntryEncoding() throws {
        let entry = HabitEntry(
            sentiment: 4,
            value: 30.0,
            note: "Great workout"
        )
        let exportEntry = ExportEntry(from: entry)

        #expect(exportEntry.sentiment == 4)
        #expect(exportEntry.value == 30.0)
        #expect(exportEntry.note == "Great workout")

        let encoder = JSONEncoder()
        let data = try encoder.encode(exportEntry)
        #expect(data.count > 0)
    }

    @Test("ExportSentimentRecord encoding")
    func testExportSentimentRecordEncoding() throws {
        let record = SentimentRecord(
            sentiment: 5,
            note: "Feeling great"
        )
        let exportRecord = ExportSentimentRecord(from: record)

        #expect(exportRecord.sentiment == 5)
        #expect(exportRecord.note == "Feeling great")

        let encoder = JSONEncoder()
        let data = try encoder.encode(exportRecord)
        #expect(data.count > 0)
    }

    @Test("ExportPreferences encoding")
    func testExportPreferencesEncoding() throws {
        let prefs = UserPreferences(
            disableHaptics: true,
            reduceMotion: true,
            highContrast: false,
            defaultReminderHour: 21,
            defaultReminderMinute: 30
        )
        let exportPrefs = ExportPreferences(from: prefs)

        #expect(exportPrefs.disableHaptics == true)
        #expect(exportPrefs.reduceMotion == true)
        #expect(exportPrefs.defaultReminderHour == 21)

        let encoder = JSONEncoder()
        let data = try encoder.encode(exportPrefs)
        #expect(data.count > 0)
    }
}

@Suite("Import Result Tests")
struct ImportResultTests {

    @Test("Total imported calculation")
    func testTotalImported() {
        let result = ImportResult(
            habitsImported: 5,
            entriesImported: 50,
            sentimentRecordsImported: 10,
            skipped: 3,
            version: "1.0"
        )

        #expect(result.totalImported == 65)
        #expect(result.skipped == 3)
    }

    @Test("Empty import")
    func testEmptyImport() {
        let result = ImportResult(
            habitsImported: 0,
            entriesImported: 0,
            sentimentRecordsImported: 0,
            skipped: 0,
            version: "1.0"
        )

        #expect(result.totalImported == 0)
    }
}

@Suite("Import Mode Tests")
struct ImportModeTests {

    @Test("Import modes exist")
    func testImportModes() {
        let merge = ImportMode.merge
        let replace = ImportMode.replace

        // Just verify they exist and are distinct
        switch merge {
        case .merge: break
        case .replace: #expect(Bool(false), "Should be merge")
        }

        switch replace {
        case .replace: break
        case .merge: #expect(Bool(false), "Should be replace")
        }
    }
}
