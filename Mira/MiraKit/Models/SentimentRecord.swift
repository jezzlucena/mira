import Foundation
import SwiftData

/// A standalone mood/sentiment log not tied to any specific habit
/// Allows users to track their baseline mood throughout the day
@Model
public final class SentimentRecord {
    /// Unique identifier
    public var id: UUID

    /// When this sentiment was recorded
    public var timestamp: Date

    /// Sentiment score on 1-6 scale (same as HabitEntry)
    public var sentiment: Int

    /// Optional note for context
    public var note: String?

    /// Context tags (e.g., "morning", "after work", "tired")
    public var contextTags: [String]

    /// Whether this record is pending cloud sync
    public var pendingSync: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sentiment: Int,
        note: String? = nil,
        contextTags: [String] = [],
        pendingSync: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sentiment = min(max(sentiment, 1), 6)
        self.note = note
        self.contextTags = contextTags
        self.pendingSync = pendingSync
    }
}

// MARK: - Sentiment Helpers (shared logic with HabitEntry)

extension SentimentRecord {
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

    public var sentimentColorHex: String {
        switch sentiment {
        case 1: return "#8E8E93"
        case 2: return "#AC8E68"
        case 3: return "#A2845E"
        case 4: return "#89AC76"
        case 5: return "#64A86B"
        case 6: return "#34C759"
        default: return "#8E8E93"
        }
    }
}
