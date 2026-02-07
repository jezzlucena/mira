import SwiftUI

/// Compact habit row for the watch habit list
struct WatchHabitRow: View {
    let habit: Habit
    let isLogged: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: habit.icon)
                .font(.body)
                .foregroundStyle(Color(hex: habit.colorHex))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                    .lineLimit(1)

                if isLogged, let latestEntry = habit.todayEntries.sorted(by: { $0.timestamp > $1.timestamp }).first {
                    if let value = latestEntry.value, let unitLabel = habit.trackingStyle.unitLabel {
                        Text("\(Int(value)) \(unitLabel)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not logged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLogged, let latestEntry = habit.todayEntries.sorted(by: { $0.timestamp > $1.timestamp }).first {
                Text(sentimentEmojiFor(latestEntry.sentiment))
                    .font(.title3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(isLogged ? "logged today" : "not logged")")
    }
}
