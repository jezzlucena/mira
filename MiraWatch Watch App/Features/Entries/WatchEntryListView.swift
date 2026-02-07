import SwiftUI
import SwiftData

/// Entry history for a habit, showing today's entries with swipe-to-delete
struct WatchEntryListView: View {
    let habit: Habit

    @Environment(\.dependencies) private var dependencies
    @State private var entries: [HabitEntry] = []
    @State private var showingLogFlow = false

    var body: some View {
        List {
            if entries.isEmpty {
                Text("No entries today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    NavigationLink(value: entry.id) {
                        WatchEntryRow(entry: entry, trackingStyle: habit.trackingStyle)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
        }
        .navigationTitle(habit.name)
        .navigationDestination(for: UUID.self) { entryId in
            if let entry = entries.first(where: { $0.id == entryId }) {
                WatchEntryDetailView(entry: entry, habit: habit, onUpdate: {
                    loadEntries()
                })
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: WatchDestination.logFlow(habit)) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadEntries()
        }
    }

    private func loadEntries() {
        entries = habit.todayEntries.sorted { $0.timestamp > $1.timestamp }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            do {
                try dependencies.entryRepository.delete(entry)
                #if os(watchOS)
                WKInterfaceDevice.current().play(.click)
                #endif
            } catch {
                // Silently fail on watch - entry will reappear on reload
            }
        }
        loadEntries()
    }
}

// MARK: - Entry Row

private struct WatchEntryRow: View {
    let entry: HabitEntry
    let trackingStyle: TrackingStyle

    var body: some View {
        HStack(spacing: 8) {
            WatchSentimentBadge(sentiment: entry.sentiment)

            VStack(alignment: .leading, spacing: 2) {
                if let value = entry.value, let unitLabel = trackingStyle.unitLabel {
                    Text("\(Int(value)) \(unitLabel)")
                        .font(.caption)
                }
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.sentimentDescription), \(formattedValue), logged at \(entry.timestamp.formatted(date: .omitted, time: .shortened))")
    }

    private var formattedValue: String {
        if let value = entry.value, let unitLabel = trackingStyle.unitLabel {
            return "\(Int(value)) \(unitLabel)"
        }
        return ""
    }
}
