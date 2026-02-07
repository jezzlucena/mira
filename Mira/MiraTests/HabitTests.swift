import Testing
import Foundation
@testable import MiraKit

@Suite("Habit Model Tests")
struct HabitTests {

    @Test("Habit initialization with defaults")
    func testHabitInitialization() {
        let habit = Habit(name: "Test Habit")

        #expect(habit.name == "Test Habit")
        #expect(habit.icon == "circle.fill")
        #expect(habit.colorHex == "#007AFF")
        #expect(habit.trackingStyle == .occurrence)
        #expect(habit.tags.isEmpty)
        #expect(habit.allEntries.isEmpty)
        #expect(habit.isLocalOnly == false)
        #expect(habit.isArchived == false)
    }

    @Test("Habit initialization with custom values")
    func testHabitCustomInitialization() {
        let habit = Habit(
            name: "Water",
            icon: "drop.fill",
            colorHex: "#34C759",
            trackingStyle: .quantity,
            tags: ["health", "hydration"],
            isLocalOnly: true
        )

        #expect(habit.name == "Water")
        #expect(habit.icon == "drop.fill")
        #expect(habit.colorHex == "#34C759")
        #expect(habit.trackingStyle == .quantity)
        #expect(habit.tags.count == 2)
        #expect(habit.isLocalOnly == true)
    }

    @Test("Tracking style properties")
    func testTrackingStyle() {
        #expect(TrackingStyle.occurrence.displayName == "Occurrence")
        #expect(TrackingStyle.duration.displayName == "Duration")
        #expect(TrackingStyle.quantity.displayName == "Quantity")

        #expect(TrackingStyle.occurrence.unitLabel == nil)
        #expect(TrackingStyle.duration.unitLabel == "minutes")
        #expect(TrackingStyle.quantity.unitLabel == "times")
    }

    @Test("Color components parsing")
    func testColorComponents() {
        let habit = Habit(name: "Test", colorHex: "#FF0000")
        let components = habit.colorComponents

        #expect(components.red == 1.0)
        #expect(components.green == 0.0)
        #expect(components.blue == 0.0)
    }

    @Test("Color components with lowercase hex")
    func testColorComponentsLowercase() {
        let habit = Habit(name: "Test", colorHex: "#00ff00")
        let components = habit.colorComponents

        #expect(components.red == 0.0)
        #expect(components.green == 1.0)
        #expect(components.blue == 0.0)
    }
}

@Suite("HabitEntry Model Tests")
struct HabitEntryTests {

    @Test("Entry initialization with required sentiment")
    func testEntryInitialization() {
        let entry = HabitEntry(sentiment: 4)

        #expect(entry.sentiment == 4)
        #expect(entry.value == nil)
        #expect(entry.note == nil)
        #expect(entry.contextTags.isEmpty)
        #expect(entry.isValid)
    }

    @Test("Sentiment clamping to valid range")
    func testSentimentClamping() {
        let low = HabitEntry(sentiment: -5)
        let high = HabitEntry(sentiment: 100)

        #expect(low.sentiment == 1)
        #expect(high.sentiment == 6)
    }

    @Test("Sentiment descriptions")
    func testSentimentDescriptions() {
        #expect(HabitEntry(sentiment: 1).sentimentDescription == "Awful")
        #expect(HabitEntry(sentiment: 2).sentimentDescription == "Rough")
        #expect(HabitEntry(sentiment: 3).sentimentDescription == "Meh")
        #expect(HabitEntry(sentiment: 4).sentimentDescription == "Okay")
        #expect(HabitEntry(sentiment: 5).sentimentDescription == "Good")
        #expect(HabitEntry(sentiment: 6).sentimentDescription == "Great")
    }

    @Test("Entry with value and note")
    func testEntryWithDetails() {
        let entry = HabitEntry(
            sentiment: 5,
            value: 30.0,
            note: "Great session",
            contextTags: ["morning", "focused"]
        )

        #expect(entry.sentiment == 5)
        #expect(entry.value == 30.0)
        #expect(entry.note == "Great session")
        #expect(entry.contextTags.count == 2)
    }

    @Test("Entry validation")
    func testEntryValidation() {
        let valid = HabitEntry(sentiment: 3)
        #expect(valid.isValid)
    }
}

@Suite("SentimentRecord Model Tests")
struct SentimentRecordTests {

    @Test("Standalone sentiment record")
    func testSentimentRecord() {
        let record = SentimentRecord(
            sentiment: 5,
            note: "Feeling good today"
        )

        #expect(record.sentiment == 5)
        #expect(record.note == "Feeling good today")
        #expect(record.sentimentDescription == "Good")
    }

    @Test("Sentiment color codes")
    func testSentimentColors() {
        #expect(SentimentRecord(sentiment: 1).sentimentColorHex == "#8E8E93")
        #expect(SentimentRecord(sentiment: 6).sentimentColorHex == "#34C759")
    }
}

@Suite("UserPreferences Model Tests")
struct UserPreferencesTests {

    @Test("Default preferences")
    func testDefaultPreferences() {
        let prefs = UserPreferences()

        #expect(prefs.disableHaptics == false)
        #expect(prefs.reduceMotion == false)
        #expect(prefs.highContrast == false)
        #expect(prefs.hasCompletedOnboarding == false)
        #expect(prefs.preferredColorScheme == .system)
    }

    @Test("Color scheme setting")
    func testColorScheme() {
        let prefs = UserPreferences()

        prefs.preferredColorScheme = .dark
        #expect(prefs.preferredColorSchemeRaw == "dark")

        prefs.preferredColorScheme = .system
        #expect(prefs.preferredColorSchemeRaw == nil)
    }

    @Test("Default reminder time")
    func testDefaultReminderTime() {
        let prefs = UserPreferences()
        let time = prefs.defaultReminderTime

        #expect(time.hour == 20)
        #expect(time.minute == 0)
    }
}
