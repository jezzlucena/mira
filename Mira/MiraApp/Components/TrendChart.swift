import SwiftUI
import Charts

/// Displays sentiment trend over time using Swift Charts
struct TrendChart: View {
    let data: [TrendDataPoint]
    var height: CGFloat = 200
    var showAxisLabels: Bool = true

    @State private var selectedPoint: TrendDataPoint?
    @Environment(\.colorScheme) private var colorScheme

    private var tooltipBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.96)
    }

    private var dataWithValues: [TrendDataPoint] {
        data.filter { $0.hasValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dataWithValues.isEmpty {
                emptyState
            } else {
                chart
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            ForEach(dataWithValues) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Sentiment", point.value!)
                )
                .foregroundStyle(gradientColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Sentiment", point.value!)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Sentiment", point.value!)
                )
                .foregroundStyle(pointColor(for: point.value!))
                .symbolSize(30)
            }

            if let selectedPoint, let val = selectedPoint.value {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        tooltipView(date: selectedPoint.date, value: val)
                    }
            }
        }
        .chartYScale(domain: 1...6)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            if showAxisLabels {
                AxisMarks(values: [1, 2, 3, 4, 5, 6]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            if showAxisLabels {
                AxisMarks(values: .stride(by: .day, count: max(1, data.count / 7))) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let date: Date = proxy.value(atX: location.x) else { return }
                        let tapped = closestPoint(to: date)
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedPoint?.id == tapped?.id {
                                selectedPoint = nil
                            } else {
                                selectedPoint = tapped
                            }
                        }
                    }
            }
        }
        .frame(height: height)
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = data.first?.date, let last = data.last?.date else {
            return Date()...Date()
        }
        return first...last
    }

    private func closestPoint(to date: Date) -> TrendDataPoint? {
        dataWithValues.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    @ViewBuilder
    private func tooltipView(date: Date, value: Double) -> some View {
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

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No data yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Start logging to see your trends")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var gradientColor: Color {
        .accentColor
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
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
}

// MARK: - Data Point

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double?

    var hasValue: Bool { value != nil }
}

// MARK: - Mini Trend Chart (for dashboard)

struct MiniTrendChart: View {
    let data: [TrendDataPoint]
    var height: CGFloat = 60

    private var dataWithValues: [TrendDataPoint] {
        data.filter { $0.hasValue }
    }

    var body: some View {
        if dataWithValues.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: height)
        } else {
            Chart(dataWithValues) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Sentiment", point.value!)
                )
                .foregroundStyle(.tint)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Sentiment", point.value!)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 1...6)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: height)
        }
    }
}

// MARK: - Heatmap View

struct HeatmapView: View {
    let data: [[HeatmapCell]]
    let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day labels
            HStack(spacing: 4) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                }
            }

            // Grid
            VStack(spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { weekIndex, week in
                    HStack(spacing: 2) {
                        ForEach(week) { cell in
                            HeatmapCellView(cell: cell)
                        }

                        // Pad incomplete weeks
                        if week.count < 7 {
                            ForEach(0..<(7 - week.count), id: \.self) { _ in
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HeatmapCellView: View {
    let cell: HeatmapCell

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .frame(width: 16, height: 16)
            .accessibilityLabel(accessibilityLabel)
    }

    private var cellColor: Color {
        guard cell.hasData, let sentiment = cell.averageSentiment else {
            return .gray.opacity(0.1)
        }

        switch Int(sentiment.rounded()) {
        case 1: return Color(hex: "#8E8E93").opacity(0.8)
        case 2: return Color(hex: "#AC8E68").opacity(0.8)
        case 3: return Color(hex: "#A2845E").opacity(0.8)
        case 4: return Color(hex: "#89AC76").opacity(0.8)
        case 5: return Color(hex: "#64A86B").opacity(0.8)
        case 6: return Color(hex: "#34C759").opacity(0.8)
        default: return .gray.opacity(0.3)
        }
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if cell.hasData, let sentiment = cell.averageSentiment {
            return "\(formatter.string(from: cell.date)): sentiment \(Int(sentiment.rounded()))"
        }
        return "\(formatter.string(from: cell.date)): no data"
    }
}

// MARK: - Bar Chart for day-of-week analysis

struct DayOfWeekChart: View {
    let data: [Int: Double] // weekday (1-7) -> average sentiment
    var height: CGFloat = 150

    @State private var selectedDay: DayData?
    @Environment(\.colorScheme) private var colorScheme

    private var tooltipBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.96)
    }

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var chartData: [DayData] {
        (1...7).map { weekday in
            DayData(
                day: dayNames[weekday - 1],
                weekday: weekday,
                value: data[weekday] ?? 0
            )
        }
    }

    var body: some View {
        Chart(chartData) { item in
            BarMark(
                x: .value("Day", item.day),
                y: .value("Sentiment", item.value)
            )
            .foregroundStyle(barColor(for: item.value))
            .cornerRadius(4)

            if let selectedDay, selectedDay.weekday == item.weekday, item.value > 0 {
                RuleMark(x: .value("Day", item.day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        dayTooltipView(day: item)
                    }
            }
        }
        .chartYScale(domain: 0...6)
        .chartYAxis {
            AxisMarks(values: [0, 2, 4, 6]) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let day: String = proxy.value(atX: location.x) else { return }
                        let tapped = chartData.first { $0.day == day }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedDay?.weekday == tapped?.weekday {
                                selectedDay = nil
                            } else {
                                selectedDay = tapped
                            }
                        }
                    }
            }
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func dayTooltipView(day: DayData) -> some View {
        VStack(spacing: 2) {
            Text(day.day)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(sentimentEmojiFor(Int(day.value.rounded())))
                    .font(.caption)
                Text(String(format: "%.1f", day.value))
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

    private func barColor(for value: Double) -> Color {
        if value == 0 { return .gray.opacity(0.3) }

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
}

private struct DayData: Identifiable {
    var id: Int { weekday }
    let day: String
    let weekday: Int
    let value: Double
}

// MARK: - Preview

#Preview("Charts") {
    let sampleData: [TrendDataPoint] = {
        let calendar = Calendar.current
        return (0..<14).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            return TrendDataPoint(date: date, value: Double.random(in: 2...5))
        }.reversed()
    }()

    ScrollView {
        VStack(spacing: 24) {
            GroupBox("Trend Chart") {
                TrendChart(data: sampleData)
            }

            GroupBox("Mini Trend") {
                MiniTrendChart(data: sampleData)
            }

            GroupBox("Day of Week") {
                DayOfWeekChart(data: [1: 3.5, 2: 4.0, 3: 3.8, 4: 4.2, 5: 4.5, 6: 5.0, 7: 4.8])
            }
        }
        .padding()
    }
}
