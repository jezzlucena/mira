import SwiftUI

/// Card displaying a habit with its status and recent sentiment
struct HabitCard: View {
    let habit: Habit
    let onTap: () -> Void
    let onQuickLog: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                habitIcon

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    statusText
                }

                Spacer()

                // Quick log or sentiment indicator
                trailingContent
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var habitIcon: some View {
        let color = Color(hex: habit.colorHex)

        Image(systemName: habit.icon)
            .font(.title2)
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(color.opacity(0.15))
            }
    }

    @ViewBuilder
    private var statusText: some View {
        if habit.isLoggedToday {
            let todayCount = habit.todayEntries.count
            Text(todayCount == 1 ? "Logged today" : "Logged \(todayCount)x today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Text("Not logged today")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if habit.isLoggedToday {
            // Show average sentiment for today
            if let avgSentiment = averageTodaySentiment {
                SentimentBadge(sentiment: Int(avgSentiment.rounded()))
            }
        } else {
            // Quick log button
            Button(action: onQuickLog) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    private var averageTodaySentiment: Double? {
        let todayEntries = habit.todayEntries
        guard !todayEntries.isEmpty else { return nil }
        let total = todayEntries.reduce(0) { $0 + $1.sentiment }
        return Double(total) / Double(todayEntries.count)
    }
}

// MARK: - Compact Habit Card (for dashboard quick log)

struct CompactHabitCard: View {
    let habit: Habit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: habit.icon)
                    .font(.title2)
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 56, height: 56)
                    .background {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.regular, in: .circle)
                    }

                Text(habit.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(CompactHabitCardStyle(isLogged: habit.isLoggedToday))
    }
}

private struct CompactHabitCardStyle: ButtonStyle {
    let isLogged: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Habit List Row

struct HabitListRow: View {
    let habit: Habit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: habit.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 32, height: 32)

                Text(habit.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Habit Entry Row

struct HabitEntryRow: View {
    let entry: HabitEntry

    var body: some View {
        HStack(spacing: 12) {
            SentimentBadge(sentiment: entry.sentiment, size: .regular)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timestamp, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if let value = entry.value, let habit = entry.habit {
                    Text(formatValue(value, style: habit.trackingStyle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !entry.contextTags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(entry.contextTags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(.quaternary)
                            }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatValue(_ value: Double, style: TrackingStyle) -> String {
        switch style {
        case .duration:
            let minutes = Int(value)
            if minutes >= 60 {
                return "\(minutes / 60)h \(minutes % 60)m"
            }
            return "\(minutes) min"
        case .quantity:
            return "\(Int(value))x"
        case .occurrence:
            return ""
        }
    }
}

// MARK: - Preview

#Preview("Habit Cards") {
    let previewHabit = Habit(
        name: "Morning Walk",
        icon: "figure.walk",
        colorHex: "#34C759",
        trackingStyle: .duration
    )

    VStack(spacing: 16) {
        HabitCard(
            habit: previewHabit,
            onTap: {},
            onQuickLog: {}
        )

        HStack(spacing: 12) {
            CompactHabitCard(habit: previewHabit, onTap: {})
            CompactHabitCard(habit: previewHabit, onTap: {})
        }

        HabitListRow(habit: previewHabit, onTap: {})
    }
    .padding()
}
