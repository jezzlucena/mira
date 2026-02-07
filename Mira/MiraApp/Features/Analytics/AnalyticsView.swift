import SwiftUI
import Charts

/// Main analytics tab showing insights and correlations
struct AnalyticsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var insights: [Insight] = []
    @State private var sentimentTrend: [TrendDataPoint] = []
    @State private var dayOfWeekData: [Int: Double] = [:]
    @State private var hourOfDayData: [Int: Double] = [:]
    @State private var correlations: [CorrelationResult] = []
    @State private var isLoading = true
    @State private var selectedPeriod = 30
    @State private var selectedCorrelation: CorrelationResult?
    @AppStorage("exampleInsightDismissed") private var exampleInsightDismissed = false
    @AppStorage("exampleCorrelationDismissed") private var exampleCorrelationDismissed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period selector
                    periodSelector

                    // Insights section
                    if !insights.isEmpty || !exampleInsightDismissed {
                        insightsSection
                    }

                    // Sentiment trend
                    trendSection

                    // Day of week analysis
                    dayOfWeekSection

                    // Correlations
                    correlationsSection
                }
                .padding()
            }
            .navigationTitle("Insights")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedPeriod) { _, _ in
                Task { await loadData() }
            }
            .sheet(item: $selectedCorrelation) { result in
                CorrelationDetailView(
                    result: result,
                    period: selectedPeriod
                )
            }
        }
    }

    // MARK: - Period Selector

    @ViewBuilder
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("7 days").tag(7)
            Text("30 days").tag(30)
            Text("90 days").tag(90)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Insights Section

    @ViewBuilder
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights")
                .font(.headline)

            if insights.isEmpty {
                exampleInsightCard
            } else {
                ForEach(insights.prefix(3)) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }

    @ViewBuilder
    private var exampleInsightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Pattern")
                        .font(.subheadline.bold())

                    Text("Your mood tends to be highest on Friday and lowest on Monday.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        exampleInsightDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                        }
                }
                .buttonStyle(.plain)
            }
            .padding()

            Text("This is an example - your key insights will appear here once the app has enough data to process.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var exampleCorrelationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Exercise")
                            .font(.subheadline.bold())

                        Text("😊")
                            .font(.caption)
                    }

                    Text("Moderate link · improves mood")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Visual strength bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.6), .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * 0.45, height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation {
                        exampleCorrelationDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                        }
                }
                .buttonStyle(.plain)
            }
            .padding()

            Text("This is an example - your habit-mood correlations will appear here once the app has enough data to process.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Trend Section

    @ViewBuilder
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trend")
                .font(.headline)

            TrendChart(data: sentimentTrend)
                .frame(height: 200)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
        }
    }

    // MARK: - Day of Week Section

    @ViewBuilder
    private var dayOfWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Day of Week")
                .font(.headline)

            DayOfWeekChart(data: dayOfWeekData)
                .frame(height: 150)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
        }
    }

    // MARK: - Correlations Section

    @ViewBuilder
    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit-Mood Correlations")
                .font(.headline)

            if correlations.isEmpty {
                if !exampleCorrelationDismissed {
                    exampleCorrelationCard
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(correlations.prefix(5)) { result in
                        CorrelationRow(result: result)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCorrelation = result
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

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load trend data and fill in empty days
            let trend = try dependencies.analyticsEngine.sentimentTrend(forLastDays: selectedPeriod)
            sentimentTrend = Self.fillMissingDays(from: trend, days: selectedPeriod)

            // Load day of week data
            dayOfWeekData = try dependencies.analyticsEngine.sentimentByDayOfWeek(forLastDays: selectedPeriod)

            // Load hour of day data
            hourOfDayData = try dependencies.analyticsEngine.sentimentByHourOfDay(forLastDays: selectedPeriod)

            // Load correlations
            correlations = try dependencies.analyticsEngine.findMoodCorrelations(days: selectedPeriod)

            // Load insights
            insights = try await dependencies.analyticsEngine.generateInsights(days: selectedPeriod)
        } catch {
            print("Failed to load analytics: \(error)")
        }
    }

    /// Builds a TrendDataPoint array covering every day in the period, using nil for days with no data
    static func fillMissingDays(from trend: [Date: Double], days: Int) -> [TrendDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0...days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let value = trend[date]
            return TrendDataPoint(date: date, value: value)
        }
        .sorted { $0.date < $1.date }
    }
}

// MARK: - Analytics Overview View (for iPad split view)

struct AnalyticsOverviewView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var sentimentTrend: [TrendDataPoint] = []
    @State private var correlations: [CorrelationResult] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary stats
                statsGrid

                // Trend
                VStack(alignment: .leading, spacing: 12) {
                    Text("30-Day Trend")
                        .font(.headline)

                    TrendChart(data: sentimentTrend)
                        .frame(height: 200)
                }

                // Top correlations
                if !correlations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Correlations")
                            .font(.headline)

                        ForEach(correlations.prefix(3)) { result in
                            CorrelationRow(result: result)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Analytics")
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Avg Mood", value: averageMood, icon: "face.smiling")
            StatCard(title: "Best Day", value: bestDay, icon: "sun.max.fill")
            StatCard(title: "Entries", value: "\(sentimentTrend.count)", icon: "list.bullet")
        }
    }

    private var averageMood: String {
        let values = sentimentTrend.compactMap(\.value)
        guard !values.isEmpty else { return "—" }
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "%.1f", avg)
    }

    private var bestDay: String {
        let withValues = sentimentTrend.filter { $0.hasValue }
        guard let best = withValues.max(by: { ($0.value ?? 0) < ($1.value ?? 0) }) else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: best.date)
    }

    private func loadData() async {
        do {
            let trend = try dependencies.analyticsEngine.sentimentTrend(forLastDays: 30)
            sentimentTrend = AnalyticsView.fillMissingDays(from: trend, days: 30)

            correlations = try dependencies.analyticsEngine.findMoodCorrelations(days: 30)
        } catch {
            print("Failed to load data: \(error)")
        }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.bold())

                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }

    private var iconName: String {
        switch insight.type {
        case .habitCorrelation: return "arrow.left.arrow.right"
        case .temporalPattern: return "calendar"
        case .healthCorrelation: return "heart.fill"
        case .milestone: return "flag.fill"
        }
    }

    private var iconColor: Color {
        switch insight.type {
        case .habitCorrelation: return .blue
        case .temporalPattern: return .orange
        case .healthCorrelation: return .red
        case .milestone: return .green
        }
    }
}

// MARK: - Correlation Row

struct CorrelationRow: View {
    let result: CorrelationResult

    private var barColor: Color {
        result.isPositive ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.habit.icon)
                .foregroundStyle(Color(hex: result.habit.colorHex))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(result.habit.name)
                        .font(.subheadline.bold())

                    if result.correlation != nil {
                        Text(result.isPositive ? "😊" : "😔")
                            .font(.caption)
                    }
                }

                Text(result.strengthDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Visual strength bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [barColor.opacity(0.6), barColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * result.normalizedStrength, height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Correlation Detail View

struct CorrelationDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let result: CorrelationResult
    let period: Int

    @State private var comparison: HabitMoodComparison?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    habitHeader

                    // Summary
                    summarySection

                    // Comparison chart
                    if let comparison, comparison.averageMoodWith != nil, comparison.averageMoodWithout != nil {
                        comparisonChart(comparison)
                    }

                    // Correlation strength
                    strengthSection

                    // Sample size
                    sampleSizeSection
                }
                .padding()
            }
            .navigationTitle("Correlation Details")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                loadComparison()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var habitHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: result.habit.icon)
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: result.habit.colorHex))
                .frame(width: 80, height: 80)
                .background {
                    Circle()
                        .fill(Color(hex: result.habit.colorHex).opacity(0.15))
                }

            Text(result.habit.name)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let comparison, let avgWith = comparison.averageMoodWith, let avgWithout = comparison.averageMoodWithout {
            let emoji = sentimentEmojiFor(Int(avgWith.rounded()))
            VStack(spacing: 8) {
                Text(summaryText(avgWith: avgWith, avgWithout: avgWithout, emoji: emoji))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    private func summaryText(avgWith: Double, avgWithout: Double, emoji: String) -> String {
        "On days you log \(result.habit.name), your mood averages \(String(format: "%.1f", avgWith)) \(emoji) vs \(String(format: "%.1f", avgWithout)) on other days."
    }

    // MARK: - Comparison Chart

    @ViewBuilder
    private func comparisonChart(_ comparison: HabitMoodComparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Comparison")
                .font(.headline)

            Chart {
                if let avgWith = comparison.averageMoodWith {
                    BarMark(
                        x: .value("Category", "With \(result.habit.name)"),
                        y: .value("Mood", avgWith)
                    )
                    .foregroundStyle(Color(hex: result.habit.colorHex))
                    .cornerRadius(8)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", avgWith))
                            .font(.caption.bold())
                    }
                }

                if let avgWithout = comparison.averageMoodWithout {
                    BarMark(
                        x: .value("Category", "Without"),
                        y: .value("Mood", avgWithout)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .cornerRadius(8)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", avgWithout))
                            .font(.caption.bold())
                    }
                }
            }
            .chartYScale(domain: 1...6)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5, 6]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text(sentimentEmojiFor(intVal))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Strength

    @ViewBuilder
    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Correlation Strength")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(result.strengthLabel)
                        .font(.subheadline.bold())

                    Spacer()

                    if result.correlation != nil {
                        Text(result.isPositive ? "Improves mood" : "Lowers mood")
                            .font(.caption)
                            .foregroundStyle(result.isPositive ? .green : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(result.isPositive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            }
                    }
                }

                // Visual bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [strengthBarColor.opacity(0.6), strengthBarColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * result.normalizedStrength, height: 10)
                    }
                }
                .frame(height: 10)

                // Scale labels
                HStack {
                    Text("Weak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Strong")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private var strengthBarColor: Color {
        result.isPositive ? .green : .orange
    }

    // MARK: - Sample Size

    @ViewBuilder
    private var sampleSizeSection: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            if let comparison {
                Text("Based on \(comparison.totalDays) days of data (\(comparison.daysWithHabit) with \(result.habit.name), \(comparison.daysWithoutHabit) without)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Based on \(result.sampleSize) days of data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Data Loading

    private func loadComparison() {
        do {
            comparison = try dependencies.analyticsEngine.moodAverageWithAndWithout(
                habit: result.habit,
                days: period
            )
        } catch {
            print("Failed to load comparison: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .withDependencies(.shared)
}
