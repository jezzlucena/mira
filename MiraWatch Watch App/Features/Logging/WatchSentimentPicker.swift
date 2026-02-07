import SwiftUI

/// Sentiment picker for watchOS (1-6 scale)
/// Horizontal swipeable carousel — selected item stays centered
struct WatchSentimentPicker: View {
    @Binding var selectedSentiment: Int
    var onConfirm: ((Int) -> Void)?

    @State private var crownValue: Double = 4.0

    // Drag tracking: position in continuous "index" space (0-based)
    // e.g. 3.0 = item at index 3 is centered, 3.4 = dragged 40% toward index 4
    @State private var currentPosition: CGFloat = 3.0
    @State private var isDragging = false

    private let itemWidth: CGFloat = 52
    private let count = 6

    var body: some View {
        VStack(spacing: 6) {
            Text("How do you feel?")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let centerX = geo.size.width / 2

                ZStack {
                    ForEach(0..<count, id: \.self) { index in
                        let value = index + 1
                        let offset = (CGFloat(index) - currentPosition) * itemWidth
                        let distance = abs(CGFloat(index) - currentPosition)
                        let isNearest = value == selectedSentiment && !isDragging

                        Text(sentimentEmojiFor(value))
                            .font(.system(size: lerp(from: 40, to: 26, t: min(distance, 2) / 2)))
                            .opacity(lerp(from: 1.0, to: 0.3, t: min(distance, 2) / 2))
                            .frame(width: itemWidth, height: itemWidth)
                            .position(x: centerX + offset, y: geo.size.height / 2)
                            .onTapGesture {
                                setSentiment(value)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentPosition = CGFloat(index)
                                }
                            }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { gesture in
                            isDragging = true
                            let startIndex = CGFloat(selectedSentiment - 1)
                            let draggedIndices = -gesture.translation.width / itemWidth
                            currentPosition = startIndex + draggedIndices
                        }
                        .onEnded { gesture in
                            isDragging = false
                            // Snap to nearest item
                            let snappedIndex = min(max(Int(currentPosition.rounded()), 0), count - 1)
                            let newValue = snappedIndex + 1
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                currentPosition = CGFloat(snappedIndex)
                            }
                            if newValue != selectedSentiment {
                                setSentiment(newValue)
                            }
                        }
                )
            }
            .frame(height: 56)
            .clipped()

            Text(sentimentDescription)
                .font(.headline)
                .foregroundStyle(sentimentColorFor(selectedSentiment))
                .animation(.easeInOut(duration: 0.15), value: selectedSentiment)

            Button("Confirm") {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.click)
                #endif
                onConfirm?(selectedSentiment)
            }
            .buttonStyle(.borderedProminent)
            .tint(sentimentColorFor(selectedSentiment))
            .padding(.top, 4)
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
                setSentiment(clamped)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentPosition = CGFloat(clamped - 1)
                }
            }
        }
        #endif
        .onAppear {
            let index = selectedSentiment - 1
            currentPosition = CGFloat(index)
            crownValue = Double(selectedSentiment)
        }
        .accessibilityLabel("Sentiment picker, current value \(selectedSentiment), \(sentimentDescription)")
        .accessibilityHint("Swipe, tap, or use the Digital Crown to adjust")
    }

    private func setSentiment(_ value: Int) {
        selectedSentiment = value
        crownValue = Double(value)
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    /// Linear interpolation
    private func lerp(from a: CGFloat, to b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * max(0, min(1, t))
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
