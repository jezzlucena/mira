import Foundation
import SwiftData

/// A habit that the user wants to track
/// Mira takes a non-judgmental approach - habits are neither "good" nor "bad"
@Model
public final class Habit {
    /// Unique identifier
    public var id: UUID

    /// User-defined name for the habit
    public var name: String

    /// SF Symbol icon name
    public var icon: String

    /// Hex color string for visual identification
    public var colorHex: String

    /// How this habit is tracked
    public var trackingStyleRaw: String

    /// User-defined tags for categorization
    public var tags: [String]

    /// All entries logged for this habit
    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    public var entries: [HabitEntry]

    /// If true, this habit will never sync to cloud (for sensitive habits)
    public var isLocalOnly: Bool

    /// Whether the habit is archived (hidden from main views but data preserved)
    public var isArchived: Bool

    /// Creation timestamp
    public var createdAt: Date

    /// Last modification timestamp
    public var updatedAt: Date

    /// Order for display (user can reorder)
    public var displayOrder: Int

    public var trackingStyle: TrackingStyle {
        get { TrackingStyle(rawValue: trackingStyleRaw) ?? .occurrence }
        set { trackingStyleRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "circle.fill",
        colorHex: String = "#007AFF",
        trackingStyle: TrackingStyle = .occurrence,
        tags: [String] = [],
        isLocalOnly: Bool = false,
        isArchived: Bool = false,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.trackingStyleRaw = trackingStyle.rawValue
        self.tags = tags
        self.entries = []
        self.isLocalOnly = isLocalOnly
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
        self.displayOrder = displayOrder
    }
}

// MARK: - Convenience Extensions

extension Habit {
    /// Returns entries for today
    public var todayEntries: [HabitEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return entries.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
    }

    /// Whether the habit has been logged today
    public var isLoggedToday: Bool {
        !todayEntries.isEmpty
    }

    /// Total count of entries
    public var totalEntryCount: Int {
        entries.count
    }

    /// Average sentiment across all entries
    public var averageSentiment: Double? {
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.sentiment }
        return Double(total) / Double(entries.count)
    }

    /// Entries from the last N days
    public func entries(forLastDays days: Int) -> [HabitEntry] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }
        return entries.filter { $0.timestamp >= startDate }
    }
}

// MARK: - Color Helpers

extension Habit {
    /// Converts hex string to RGB components
    public var colorComponents: (red: Double, green: Double, blue: Double) {
        var hex = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        return (
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
