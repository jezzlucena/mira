import SwiftUI

/// Single entry detail view with edit/delete actions
struct WatchEntryDetailView: View {
    let entry: HabitEntry
    let habit: Habit
    var onUpdate: (() -> Void)?

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sentiment
                VStack(spacing: 4) {
                    Text(sentimentEmojiFor(entry.sentiment))
                        .font(.system(size: 36))
                    Text(entry.sentimentDescription)
                        .font(.headline)
                        .foregroundStyle(sentimentColorFor(entry.sentiment))
                }

                Divider()

                // Value (if applicable)
                if let value = entry.value, let unitLabel = habit.trackingStyle.unitLabel {
                    VStack(spacing: 2) {
                        Text("\(Int(value))")
                            .font(.title2.bold())
                        Text(unitLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                // Timestamp
                VStack(spacing: 2) {
                    Text(entry.timestamp, style: .time)
                        .font(.body)
                    Text(entry.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Actions
                Button("Edit") {
                    showingEditSheet = true
                }
                .buttonStyle(.bordered)

                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Entry")
        .confirmationDialog("Delete Entry?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingEditSheet) {
            WatchEditEntryView(entry: entry, habit: habit) {
                onUpdate?()
                showingEditSheet = false
            }
        }
    }

    private func deleteEntry() {
        do {
            try dependencies.entryRepository.delete(entry)
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
            onUpdate?()
            dismiss()
        } catch {
            // Error deleting - will stay on screen
        }
    }
}
