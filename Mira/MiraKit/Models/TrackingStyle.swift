import Foundation

/// Defines how a habit is tracked
public enum TrackingStyle: String, Codable, CaseIterable, Identifiable {
    /// Simple yes/no occurrence tracking
    case occurrence
    /// Duration-based tracking (e.g., meditation minutes)
    case duration
    /// Quantity-based tracking (e.g., glasses of water)
    case quantity

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .occurrence: return "Occurrence"
        case .duration: return "Duration"
        case .quantity: return "Quantity"
        }
    }

    public var description: String {
        switch self {
        case .occurrence: return "Track when something happens"
        case .duration: return "Track how long (minutes)"
        case .quantity: return "Track how many"
        }
    }

    public var unitLabel: String? {
        switch self {
        case .occurrence: return nil
        case .duration: return "minutes"
        case .quantity: return "times"
        }
    }

    public var icon: String {
        switch self {
        case .occurrence: return "checkmark.circle"
        case .duration: return "timer"
        case .quantity: return "number"
        }
    }
}
