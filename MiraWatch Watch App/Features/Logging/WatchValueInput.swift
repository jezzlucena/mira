import SwiftUI

/// Digital Crown-driven value input for duration/quantity tracking styles
struct WatchValueInput: View {
    let trackingStyle: TrackingStyle
    @Binding var value: Double
    var onConfirm: ((Double) -> Void)?

    @State private var crownValue: Double = 0

    private var stepSize: Double {
        switch trackingStyle {
        case .duration: return 5.0   // 5-minute increments
        case .quantity: return 1.0   // single unit increments
        case .occurrence: return 1.0
        }
    }

    private var maxValue: Double {
        switch trackingStyle {
        case .duration: return 480.0  // 8 hours
        case .quantity: return 100.0
        case .occurrence: return 1.0
        }
    }

    private var unitLabel: String {
        trackingStyle.unitLabel ?? ""
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("How much?")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedValue)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: value)

            Text(unitLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    adjustValue(by: -stepSize)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button {
                    adjustValue(by: stepSize)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            Button("Confirm") {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.click)
                #endif
                onConfirm?(value)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        #if os(watchOS)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: maxValue,
            by: stepSize,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let clamped = min(max(newValue, 0), maxValue)
            if clamped != value {
                value = clamped
            }
        }
        .onAppear {
            crownValue = value
        }
        #endif
        .accessibilityLabel("\(formattedValue) \(unitLabel)")
        .accessibilityHint("Use the Digital Crown to adjust value")
    }

    private var formattedValue: String {
        switch trackingStyle {
        case .duration:
            let hours = Int(value) / 60
            let minutes = Int(value) % 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)"
        case .quantity:
            return "\(Int(value))"
        case .occurrence:
            return ""
        }
    }

    private func adjustValue(by amount: Double) {
        let newValue = min(max(value + amount, 0), maxValue)
        value = newValue
        crownValue = newValue
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}
