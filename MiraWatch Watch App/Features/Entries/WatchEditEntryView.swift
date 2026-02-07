import SwiftUI

/// Edit sentiment and value for an existing entry
struct WatchEditEntryView: View {
    let entry: HabitEntry
    let habit: Habit
    var onSave: (() -> Void)?

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var sentiment: Int
    @State private var value: Double
    @State private var step: EditStep = .sentiment

    init(entry: HabitEntry, habit: Habit, onSave: (() -> Void)? = nil) {
        self.entry = entry
        self.habit = habit
        self.onSave = onSave
        _sentiment = State(initialValue: entry.sentiment)
        _value = State(initialValue: entry.value ?? 0)
    }

    private var needsValue: Bool {
        habit.trackingStyle != .occurrence
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .sentiment:
                    WatchSentimentPicker(selectedSentiment: $sentiment) { _ in
                        if needsValue {
                            withAnimation {
                                step = .value
                            }
                        } else {
                            saveChanges()
                        }
                    }

                case .value:
                    WatchValueInput(trackingStyle: habit.trackingStyle, value: $value) { _ in
                        saveChanges()
                    }
                }
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        do {
            let newValue: Double? = needsValue ? value : nil
            try dependencies.entryRepository.update(
                entry,
                sentiment: sentiment,
                value: newValue
            )
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
            onSave?()
            dismiss()
        } catch {
            // Error saving - stay on screen
        }
    }
}

private enum EditStep {
    case sentiment
    case value
}
