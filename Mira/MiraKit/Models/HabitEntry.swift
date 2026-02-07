import Foundation
import SwiftData

/// A single logged entry for a habit
/// Every entry REQUIRES a sentiment score - this is core to Mira's correlation-based insights
@Model
public final class HabitEntry {
    /// Unique identifier
    public var id: UUID = UUID()

    /// The habit this entry belongs to
    public var habit: Habit?

    /// When this entry was logged
    public var timestamp: Date = Date()

    /// MANDATORY sentiment score on 1-6 scale
    /// 1 = Very low mood, 6 = Very high mood
    /// Using 1-6 (even number) to avoid neutral middle option - forces reflection
    public var sentiment: Int = 4

    /// Optional value for duration/quantity tracking styles
    /// For occurrence style, this is nil
    public var value: Double?

    /// Optional user note for context
    public var note: String?

    /// Context tags for this specific entry (e.g., "stressed", "social", "alone")
    public var contextTags: [String] = []

    /// Whether this entry is pending cloud sync
    public var pendingSync: Bool = false

    /// Creation timestamp (for sync conflict resolution)
    public var createdAt: Date = Date()

    public init(
        id: UUID = UUID(),
        habit: Habit? = nil,
        timestamp: Date = Date(),
        sentiment: Int,
        value: Double? = nil,
        note: String? = nil,
        contextTags: [String] = [],
        pendingSync: Bool = false
    ) {
        self.id = id
        self.habit = habit
        self.timestamp = timestamp
        // Clamp sentiment to valid range
        self.sentiment = min(max(sentiment, 1), 6)
        self.value = value
        self.note = note
        self.contextTags = contextTags
        self.pendingSync = pendingSync
        self.createdAt = Date()
    }
}

// MARK: - Sentiment Helpers

extension HabitEntry {
    /// Sentiment description for accessibility and display
    public var sentimentDescription: String {
        switch sentiment {
        case 1: return "Awful"
        case 2: return "Rough"
        case 3: return "Meh"
        case 4: return "Okay"
        case 5: return "Good"
        case 6: return "Great"
        default: return "Unknown"
        }
    }

    /// Color representation for the sentiment (as hex)
    public var sentimentColorHex: String {
        switch sentiment {
        case 1: return "#8E8E93" // Gray
        case 2: return "#AC8E68" // Muted tan
        case 3: return "#A2845E" // Light brown
        case 4: return "#89AC76" // Soft green
        case 5: return "#64A86B" // Medium green
        case 6: return "#34C759" // Bright green
        default: return "#8E8E93"
        }
    }

    /// Emoji for sentiment visualization
    public var sentimentEmoji: String {
        switch sentiment {
        case 1: return "😞"
        case 2: return "😔"
        case 3: return "😕"
        case 4: return "🙂"
        case 5: return "😊"
        case 6: return "😄"
        default: return "🙂"
        }
    }
}

// MARK: - Validation

extension HabitEntry {
    /// Validates that the entry has valid data
    public var isValid: Bool {
        sentiment >= 1 && sentiment <= 6
    }
}
