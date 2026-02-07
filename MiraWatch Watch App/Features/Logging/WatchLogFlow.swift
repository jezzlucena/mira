import SwiftUI

/// Multi-step log coordinator for watchOS
/// Step 1: Sentiment picker (always)
/// Step 2: Value input (duration/quantity only)
/// Step 3: Confirmation (auto-dismiss)
struct WatchLogFlow: View {
    let habit: Habit

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var step: LogStep = .sentiment
    @State private var sentiment: Int = 4
    @State private var value: Double = 0
    @State private var errorMessage: String?

    private var needsValue: Bool {
        habit.trackingStyle != .occurrence
    }

    var body: some View {
        Group {
            switch step {
            case .sentiment:
                WatchSentimentPicker(selectedSentiment: $sentiment) { _ in
                    if needsValue {
                        withAnimation {
                            step = .value
                        }
                    } else {
                        saveEntry()
                    }
                }
                .navigationTitle(habit.name)

            case .value:
                WatchValueInput(trackingStyle: habit.trackingStyle, value: $value) { _ in
                    saveEntry()
                }
                .navigationTitle(habit.name)

            case .confirmation:
                WatchConfirmationView(habitName: habit.name) {
                    dismiss()
                }

            case .error:
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text(errorMessage ?? "Something went wrong")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveEntry() {
        do {
            let entryValue: Double? = needsValue ? value : nil
            try dependencies.habitService.logEntry(
                for: habit,
                sentiment: sentiment,
                value: entryValue
            )

            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif

            withAnimation {
                step = .confirmation
            }
        } catch {
            errorMessage = error.localizedDescription
            step = .error
        }
    }
}

// MARK: - Log Steps

private enum LogStep {
    case sentiment
    case value
    case confirmation
    case error
}
