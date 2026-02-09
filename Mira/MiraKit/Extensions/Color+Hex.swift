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

// MARK: - Color to Hex

extension Color {
    /// Converts a Color back to a hex string (e.g. "#FF3B30")
    public func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#007AFF" }
        return String(
            format: "#%02X%02X%02X",
            Int(rgbColor.redComponent * 255),
            Int(rgbColor.greenComponent * 255),
            Int(rgbColor.blueComponent * 255)
        )
        #else
        return "#007AFF"
        #endif
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
