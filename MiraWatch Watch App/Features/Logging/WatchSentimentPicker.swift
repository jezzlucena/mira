import SwiftUI

/// Digital Crown-driven sentiment picker for watchOS (1-6 scale)
struct WatchSentimentPicker: View {
    @Binding var selectedSentiment: Int
    var onConfirm: ((Int) -> Void)?

    @State private var crownValue: Double = 3.5
    @State private var isScrolling = false

    var body: some View {
        VStack(spacing: 8) {
            Text("How do you feel?")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(sentimentEmojiFor(selectedSentiment))
                .font(.system(size: 48))
                .animation(.easeInOut(duration: 0.15), value: selectedSentiment)

            Text(sentimentDescription)
                .font(.headline)
                .foregroundStyle(sentimentColorFor(selectedSentiment))

            HStack(spacing: 4) {
                ForEach(1...6, id: \.self) { value in
                    Circle()
                        .fill(value == selectedSentiment ? sentimentColorFor(value) : Color.gray.opacity(0.3))
                        .frame(width: value == selectedSentiment ? 10 : 6, height: value == selectedSentiment ? 10 : 6)
                        .animation(.easeInOut(duration: 0.15), value: selectedSentiment)
                }
            }
            .padding(.top, 4)

            Button("Confirm") {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.click)
                #endif
                onConfirm?(selectedSentiment)
            }
            .buttonStyle(.borderedProminent)
            .tint(sentimentColorFor(selectedSentiment))
            .padding(.top, 8)
        }
        #if os(watchOS)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 1.0,
            through: 6.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let clamped = min(max(Int(newValue.rounded()), 1), 6)
            if clamped != selectedSentiment {
                selectedSentiment = clamped
            }
        }
        .onAppear {
            crownValue = Double(selectedSentiment)
        }
        #endif
        .accessibilityLabel("Sentiment picker, current value \(selectedSentiment), \(sentimentDescription)")
        .accessibilityHint("Use the Digital Crown to adjust")
    }

    private var sentimentDescription: String {
        switch selectedSentiment {
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
