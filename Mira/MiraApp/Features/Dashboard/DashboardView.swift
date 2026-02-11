import SwiftUI
import Charts

/// Main dashboard showing today's summary and quick log
struct DashboardView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var summary: DaySummary?
    @State private var habits: [Habit] = []
    @State private var recentSentiments: [TrendDataPoint] = []
    @State private var quickLogPresentation: QuickLogPresentation?
    @State private var isLoading = true
    @State private var selectedTrendPoint: TrendDataPoint?
    @State private var selectedEntryForEdit: HabitEntry?

    private struct QuickLogPresentation: Identifiable {
        let id = UUID()
        let habit: Habit?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's mood summary
                    moodSummaryCard

                    // Quick log section
                    quickLogSection

                    // Recent trend
                    trendSection

                    // Today's activity
                    todayActivitySection
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        quickLogPresentation = QuickLogPresentation(habit: nil)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(item: $quickLogPresentation) { presentation in
                QuickLogSheet(
                    habit: presentation.habit,
                    onComplete: {
                        quickLogPresentation = nil
                        Task { await loadData() }
                    }
                )
            }
            .sheet(item: $selectedEntryForEdit) { entry in
                if let habit = entry.habit {
                    EditEntrySheet(entry: entry, habit: habit) {
                        selectedEntryForEdit = nil
                        Task { await loadData() }
                    }
                }
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Mood Summary Card

    @ViewBuilder
    private var moodSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.title2.bold())

                    if let avg = summary?.averageSentiment {
                        HStack(spacing: 8) {
                            SentimentBadge(sentiment: Int(avg.rounded()), size: .large)
                            Text("Average mood today")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No entries yet today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Mini mood check-in button
                Button {
                    quickLogPresentation = QuickLogPresentation(habit: nil)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                        Text("Log")
                            .font(.caption)
                    }
                    .frame(width: 70, height: 70)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.clear)
                            .glassEffect()
                    }
                }
                .buttonStyle(.plain)
            }

        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Quick Log Section

    @ViewBuilder
    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Log")
                .font(.headline)

            if habits.isEmpty {
                ContentUnavailableView(
                    "No Habits Yet",
                    systemImage: "plus.circle",
                    description: Text("Create your first habit to start logging")
                )
                .frame(height: 150)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(habits.filter { !$0.isLoggedToday }) { habit in
                            CompactHabitCard(habit: habit) {
                                quickLogPresentation = QuickLogPresentation(habit: habit)
                            }
                        }

                        // Show logged habits with less emphasis
                        ForEach(habits.filter { $0.isLoggedToday }) { habit in
                            CompactHabitCard(habit: habit) {
                                quickLogPresentation = QuickLogPresentation(habit: habit)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Trend Section

    @Environment(\.colorScheme) private var colorScheme

    private var tooltipBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.96)
    }

    @ViewBuilder
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline)

                Spacer()

                if let avg = weekAverage {
                    HStack(spacing: 4) {
                        Text(sentimentEmojiFor(Int(avg.rounded())))
                            .font(.caption)
                        Text(String(format: "%.1f", avg))
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("avg")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            VStack(spacing: 12) {
                // Chart
                Chart {
                    ForEach(recentSentiments) { point in
                        if let value = point.value {
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Sentiment", value)
                            )
                            .foregroundStyle(.tint)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Sentiment", value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Sentiment", value)
                            )
                            .foregroundStyle(pointColor(for: value))
                            .symbolSize(40)
                        }
                    }

                    if let selected = selectedTrendPoint, let val = selected.value {
                        RuleMark(x: .value("Date", selected.date))
                            .foregroundStyle(.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                weekTooltip(date: selected.date, value: val)
                            }
                    }
                }
                .chartYScale(domain: 1...6)
                .chartXScale(domain: weekXDomain)
                .chartYAxis {
                    AxisMarks(values: [1, 3, 6]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text(sentimentEmojiFor(intVal))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(weekDayLabel(for: date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let date: Date = proxy.value(atX: location.x) else { return }
                                let closest = recentSentiments.filter(\.hasValue).min(by: {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                })
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedTrendPoint?.id == closest?.id {
                                        selectedTrendPoint = nil
                                    } else {
                                        selectedTrendPoint = closest
                                    }
                                }
                            }
                    }
                }
                .frame(height: 120)

                // Day entry counts
                HStack(spacing: 0) {
                    ForEach(recentSentiments) { point in
                        VStack(spacing: 2) {
                            if point.hasValue, let value = point.value {
                                Text(sentimentEmojiFor(Int(value.rounded())))
                                    .font(.caption)
                            } else {
                                Text("–")
                                    .font(.caption)
                                    .foregroundStyle(.quaternary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private func weekTooltip(date: Date, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(sentimentEmojiFor(Int(value.rounded())))
                    .font(.caption)
                Text(String(format: "%.1f", value))
                    .font(.caption.bold().monospacedDigit())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(tooltipBackground)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
    }

    private var weekAverage: Double? {
        let values = recentSentiments.compactMap(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var weekXDomain: ClosedRange<Date> {
        guard let first = recentSentiments.first?.date, let last = recentSentiments.last?.date else {
            return Date()...Date()
        }
        return first...last
    }

    private func weekDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func pointColor(for value: Double) -> Color {
        switch Int(value.rounded()) {
        case 1: return Color(hex: "#8E8E93")
        case 2: return Color(hex: "#AC8E68")
        case 3: return Color(hex: "#A2845E")
        case 4: return Color(hex: "#89AC76")
        case 5: return Color(hex: "#64A86B")
        case 6: return Color(hex: "#34C759")
        default: return .gray
        }
    }

    // MARK: - Today's Activity Section

    @ViewBuilder
    private var todayActivitySection: some View {
        if let entries = summary?.entries, !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Activity")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(entries.prefix(10)) { entry in
                        if let habit = entry.habit {
                            HStack(spacing: 12) {
                                Image(systemName: habit.icon)
                                    .foregroundStyle(Color(hex: habit.colorHex))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.name)
                                        .font(.subheadline)
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                SentimentBadge(sentiment: entry.sentiment)

                                Image(systemName: "pencil")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntryForEdit = entry
                            }
                        }
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            habits = try dependencies.habitRepository.fetchAll()
            summary = try dependencies.habitService.getTodaySummary()

            // Load recent sentiment trend (7 past days + today)
            let trend = try dependencies.analyticsEngine.sentimentTrend(forLastDays: 7)
            recentSentiments = AnalyticsView.fillMissingDays(from: trend, days: 7)
        } catch {
            print("Failed to load dashboard data: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .withDependencies(.shared)
}
