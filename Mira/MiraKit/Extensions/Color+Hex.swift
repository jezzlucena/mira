import SwiftUI

// MARK: - Color Extension

extension Color {
    public init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Sentiment Helpers

/// Returns the emoji for a sentiment value (1-6 scale)
public func sentimentEmojiFor(_ value: Int) -> String {
    switch value {
    case 1: return "😞"
    case 2: return "😔"
    case 3: return "😕"
    case 4: return "🙂"
    case 5: return "😊"
    case 6: return "😄"
    default: return "🙂"
    }
}

/// Returns the Color for a sentiment value (1-6 scale)
public func sentimentColorFor(_ value: Int) -> Color {
    switch value {
    case 1: return Color(hex: "#8E8E93")
    case 2: return Color(hex: "#AC8E68")
    case 3: return Color(hex: "#A2845E")
    case 4: return Color(hex: "#89AC76")
    case 5: return Color(hex: "#64A86B")
    case 6: return Color(hex: "#34C759")
    default: return .gray
    }
}
