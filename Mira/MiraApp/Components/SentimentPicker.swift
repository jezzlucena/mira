import SwiftUI

/// Interactive sentiment picker with Liquid Glass buttons
/// Uses 1-6 scale (even number to avoid neutral middle option)
struct SentimentPicker: View {
    @Binding var selectedSentiment: Int?
    var onSelect: ((Int) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sentimentNamespace

    var body: some View {
        VStack(spacing: 16) {
            Text("How are you feeling?")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(1...6, id: \.self) { value in
                    SentimentButton(
                        value: value,
                        isSelected: selectedSentiment == value,
                        namespace: sentimentNamespace
                    ) {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedSentiment = value
                        }
                        onSelect?(value)
                    }
                }
            }

            if let selected = selectedSentiment {
                Text(sentimentLabel(for: selected))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding()
    }

    private func sentimentLabel(for value: Int) -> String {
        switch value {
        case 1: return "Awful"
        case 2: return "Rough"
        case 3: return "Meh"
        case 4: return "Okay"
        case 5: return "Good"
        case 6: return "Great"
        default: return ""
        }
    }
}

// MARK: - Individual Sentiment Button

private struct SentimentButton: View {
    let value: Int
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(sentimentEmoji)
                .font(.title)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        Circle()
                            .fill(sentimentColor)
                            .glassEffect(.regular.tint(sentimentColor), in: .circle)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    } else {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.regular, in: .circle)
                    }
                }
        }
        .buttonStyle(SentimentButtonStyle())
        .accessibilityLabel("\(value), \(sentimentDescription)")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    }

    private var sentimentColor: Color {
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

    private var sentimentEmoji: String {
        sentimentEmojiFor(value)
    }

    private var sentimentDescription: String {
        switch value {
        case 1: return "Awful"
        case 2: return "Rough"
        case 3: return "Meh"
        case 4: return "Okay"
        case 5: return "Good"
        case 6: return "Great"
        default: return ""
        }
    }
}

private struct SentimentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Compact Sentiment Picker (for quick log)

struct CompactSentimentPicker: View {
    @Binding var selectedSentiment: Int?
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...6, id: \.self) { value in
                CompactSentimentButton(
                    value: value,
                    isSelected: selectedSentiment == value
                ) {
                    selectedSentiment = value
                    onSelect?(value)
                }
            }
        }
    }
}

private struct CompactSentimentButton: View {
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(sentimentEmojiFor(value))
                .font(isSelected ? .title3 : .body)
                .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                .opacity(isSelected ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("\(value), \(sentimentDescription)")
    }

    private var sentimentDescription: String {
        switch value {
        case 1: return "Awful"
        case 2: return "Rough"
        case 3: return "Meh"
        case 4: return "Okay"
        case 5: return "Good"
        case 6: return "Great"
        default: return ""
        }
    }
}

// MARK: - Sentiment Display (read-only)

struct SentimentBadge: View {
    let sentiment: Int
    var size: SentimentBadgeSize = .regular

    var body: some View {
        Text(sentimentEmojiFor(sentiment))
            .font(size.emojiFont)
            .padding(.horizontal, size.padding)
            .padding(.vertical, size.padding / 2)
            .background {
                Capsule()
                    .fill(sentimentColor.opacity(0.15))
            }
    }

    private var sentimentColor: Color {
        switch sentiment {
        case 1: return Color(hex: "#8E8E93")
        case 2: return Color(hex: "#AC8E68")
        case 3: return Color(hex: "#A2845E")
        case 4: return Color(hex: "#89AC76")
        case 5: return Color(hex: "#64A86B")
        case 6: return Color(hex: "#34C759")
        default: return .gray
        }
    }
}

enum SentimentBadgeSize {
    case compact
    case regular
    case large

    var dotSize: CGFloat {
        switch self {
        case .compact: return 8
        case .regular: return 10
        case .large: return 12
        }
    }

    var font: Font {
        switch self {
        case .compact: return .caption2
        case .regular: return .caption
        case .large: return .subheadline
        }
    }

    var emojiFont: Font {
        switch self {
        case .compact: return .caption2
        case .regular: return .body
        case .large: return .title3
        }
    }

    var padding: CGFloat {
        switch self {
        case .compact: return 4
        case .regular: return 8
        case .large: return 10
        }
    }
}

// sentimentEmojiFor() and Color(hex:) are defined in MiraKit/Extensions/Color+Hex.swift

// MARK: - Preview

#Preview("Sentiment Pickers") {
    VStack(spacing: 32) {
        SentimentPicker(selectedSentiment: .constant(4))

        CompactSentimentPicker(selectedSentiment: .constant(3))

        HStack(spacing: 8) {
            SentimentBadge(sentiment: 1, size: .compact)
            SentimentBadge(sentiment: 3, size: .regular)
            SentimentBadge(sentiment: 6, size: .large)
        }
    }
    .padding()
}
