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
    @State private var entryDate: Date
    @State private var step: EditStep = .sentiment

    init(entry: HabitEntry, habit: Habit, onSave: (() -> Void)? = nil) {
        self.entry = entry
        self.habit = habit
        self.onSave = onSave
        _sentiment = State(initialValue: entry.sentiment)
        _value = State(initialValue: entry.value ?? 0)
        _entryDate = State(initialValue: entry.timestamp)
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
                            withAnimation {
                                step = .dateTime
                            }
                        }
                    }

                case .value:
                    WatchValueInput(trackingStyle: habit.trackingStyle, value: $value) { _ in
                        withAnimation {
                            step = .dateTime
                        }
                    }

                case .dateTime:
                    ScrollView {
                        VStack(spacing: 12) {
                            DatePicker("When", selection: $entryDate, in: ...Date())
                                .datePickerStyle(.automatic)

                            Button("Save") {
                                saveChanges()
                            }
                            .buttonStyle(.borderedProminent)
                        }
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
                value: newValue,
                timestamp: entryDate
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
    case dateTime
}
