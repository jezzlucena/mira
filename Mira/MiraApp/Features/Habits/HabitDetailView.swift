import SwiftUI
import Charts

/// Detailed view of a habit with history and stats
struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.dependencies) private var dependencies
    @State private var entries: [HabitEntry] = []
    @State private var stats: HabitStats?
    @State private var heatmapData: [[HeatmapCell]] = []
    @State private var showEditSheet = false
    @State private var showQuickLog = false
    @State private var selectedPeriod = 30
    @State private var selectedEntryForEdit: HabitEntry?
    @State private var entryToDelete: HabitEntry?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerCard

                // Stats overview
                statsSection

                // Heatmap
                heatmapSection

                // Recent entries
                entriesSection
            }
            .padding()
        }
        .navigationTitle(habit.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showQuickLog = true
                    } label: {
                        Label("Log Entry", systemImage: "plus")
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Habit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            CreateEditHabitSheet(mode: .edit(habit)) { _ in
                Task { await loadData() }
            }
        }
        .sheet(isPresented: $showQuickLog) {
            QuickLogSheet(habit: habit) {
                showQuickLog = false
                Task { await loadData() }
            }
        }
        .sheet(item: $selectedEntryForEdit) { entry in
            EditEntrySheet(entry: entry, habit: habit) {
                selectedEntryForEdit = nil
                Task { await loadData() }
            }
        }
        .alert("Delete Entry", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this entry? This cannot be undone.")
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Header Card

    @ViewBuilder
    private var headerCard: some View {
        HStack(spacing: 16) {
            Image(systemName: habit.icon)
                .font(.largeTitle)
                .foregroundStyle(Color(hex: habit.colorHex))
                .frame(width: 64, height: 64)
                .background {
                    Circle()
                        .fill(Color(hex: habit.colorHex).opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    Label(habit.trackingStyle.displayName, systemImage: habit.trackingStyle.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if habit.isLocalOnly {
                        Label("Local", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Quick log button
            Button {
                showQuickLog = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Statistics")
                    .font(.headline)

                Spacer()

                Picker("Period", selection: $selectedPeriod) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if let stats = stats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Total Entries",
                        value: "\(stats.totalEntries)",
                        icon: "number"
                    )

                    StatCard(
                        title: "Avg Sentiment",
                        value: stats.averageSentiment.map { String(format: "%.1f", $0) } ?? "—",
                        icon: "face.smiling",
                        color: sentimentColor(for: stats.averageSentiment)
                    )

                    StatCard(
                        title: "Days Active",
                        value: "\(stats.entriesPerDay.count)",
                        icon: "calendar"
                    )

                    if habit.trackingStyle != .occurrence, let totalValue = stats.totalValue {
                        StatCard(
                            title: totalValueTitle,
                            value: formattedTotalValue(totalValue),
                            icon: totalValueIcon,
                            color: Color(hex: habit.colorHex)
                        )
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
            }
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task { await loadData() }
        }
    }

    // MARK: - Activity Section

    @ViewBuilder
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            switch selectedPeriod {
            case 7:
                WeekActivityWidget(data: heatmapData, habit: habit)
            case 90:
                let months = splitIntoMonths(heatmapData)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                        MonthActivityWidget(title: month.title, data: month.weeks, habit: habit)
                    }
                }
            default:
                MonthActivityWidget(title: monthTitle(for: Date(), offset: 0), data: heatmapData, habit: habit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
            }
        }
    }

    private struct MonthSlice {
        let title: String
        let weeks: [[HeatmapCell]]
    }

    private func monthTitle(for date: Date, offset: Int) -> String {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .month, value: -offset, to: date) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: target)
    }

    private func splitIntoMonths(_ data: [[HeatmapCell]]) -> [MonthSlice] {
        let calendar = Calendar.current
        let allCells = data.flatMap { $0 }
        guard !allCells.isEmpty else { return [] }

        // Group cells by month
        var cellsByMonth: [(key: DateComponents, cells: [HeatmapCell])] = []
        var current: (key: DateComponents, cells: [HeatmapCell])? = nil

        for cell in allCells.sorted(by: { $0.date < $1.date }) {
            let comps = calendar.dateComponents([.year, .month], from: cell.date)
            if let cur = current, cur.key == comps {
                current?.cells.append(cell)
            } else {
                if let cur = current {
                    cellsByMonth.append(cur)
                }
                current = (key: comps, cells: [cell])
            }
        }
        if let cur = current {
            cellsByMonth.append(cur)
        }

        // Convert each month's cells into week rows
        return cellsByMonth.map { month in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let title: String
            if let year = month.key.year, let monthNum = month.key.month,
               let date = calendar.date(from: DateComponents(year: year, month: monthNum, day: 1)) {
                title = formatter.string(from: date)
            } else {
                title = ""
            }

            // Chunk into weeks (7-day rows)
            var weeks: [[HeatmapCell]] = []
            var week: [HeatmapCell] = []

            // Pad the start to align with the weekday
            if let first = month.cells.first {
                let weekday = calendar.component(.weekday, from: first.date)
                let padding = weekday - calendar.firstWeekday
                let padCount = padding >= 0 ? padding : padding + 7
                for i in 0..<padCount {
                    let padDate = calendar.date(byAdding: .day, value: -(padCount - i), to: first.date)!
                    week.append(HeatmapCell(date: padDate, entryCount: 0, averageSentiment: nil))
                }
            }

            for cell in month.cells {
                week.append(cell)
                if week.count == 7 {
                    weeks.append(week)
                    week = []
                }
            }
            if !week.isEmpty {
                weeks.append(week)
            }

            return MonthSlice(title: title, weeks: weeks)
        }
    }

    // MARK: - Entries Section

    @ViewBuilder
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Entries (\(selectedPeriod) days)")
                    .font(.headline)

                Spacer()

                if entries.count > 10 {
                    NavigationLink("See All") {
                        AllEntriesView(habit: habit)
                    }
                    .font(.subheadline)
                }
            }

            if entries.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Tap + to log your first entry")
                )
                .frame(height: 150)
            } else {
                entriesList
            }
        }
    }

    private func entriesListHeight(entryCount: Int, groupCount: Int) -> CGFloat {
        let h = CGFloat(entryCount) * 64 + CGFloat(groupCount) * 30
        return min(h, 800)
    }

    @ViewBuilder
    private var entriesList: some View {
        let grouped = groupedEntries(from: Array(entries.prefix(10)))
        let listHeight = entriesListHeight(entryCount: entries.prefix(10).count, groupCount: grouped.count)
        entriesListContent(grouped: grouped)
            .frame(height: listHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
    }

    @ViewBuilder
    private func entriesListContent(grouped: [EntryGroup]) -> some View {
        List {
            ForEach(grouped, id: \.date) { group in
                Section {
                    ForEach(group.entries) { entry in
                        entryRow(for: entry)
                    }
                } header: {
                    Text(formatDayHeader(group.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        #if !os(macOS)
        .listSectionSpacing(0)
        #endif
        .scrollDisabled(true)
    }

    @ViewBuilder
    private func entryRow(for entry: HabitEntry) -> some View {
        HabitEntryRow(entry: entry)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedEntryForEdit = entry
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    entryToDelete = entry
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    selectedEntryForEdit = entry
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .contextMenu {
                Button {
                    selectedEntryForEdit = entry
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    entryToDelete = entry
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    // MARK: - Helpers

    private struct EntryGroup {
        let date: Date
        let entries: [HabitEntry]
    }

    private func groupedEntries(from entries: [HabitEntry]) -> [EntryGroup] {
        let calendar = Calendar.current
        var grouped: [Date: [HabitEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            grouped[day, default: []].append(entry)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { EntryGroup(date: $0.key, entries: $0.value) }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func deleteEntry(_ entry: HabitEntry) {
        do {
            try dependencies.entryRepository.delete(entry)
            entries.removeAll { $0.id == entry.id }
            entryToDelete = nil
            Task { await loadData() }
        } catch {
            print("Failed to delete entry: \(error)")
        }
    }

    private func loadData() async {
        do {
            let allEntries = try dependencies.entryRepository.fetchAll(for: habit)
            entries = allEntries.filter { entry in
                entry.timestamp >= Calendar.current.date(byAdding: .day, value: -selectedPeriod, to: Date())!
            }
            stats = try dependencies.habitService.getHabitStats(for: habit, days: selectedPeriod)

            let weeks: Int
            switch selectedPeriod {
            case 7: weeks = 1
            case 90: weeks = 13
            default: weeks = 5
            }
            heatmapData = try dependencies.analyticsEngine.generateHeatmapData(for: habit, weeks: weeks)
        } catch {
            print("Failed to load habit data: \(error)")
        }
    }

    private var totalValueTitle: String {
        switch habit.trackingStyle {
        case .duration: return "Total Time"
        case .quantity: return "Total Count"
        case .occurrence: return ""
        }
    }

    private var totalValueIcon: String {
        switch habit.trackingStyle {
        case .duration: return "clock.fill"
        case .quantity: return "sum"
        case .occurrence: return ""
        }
    }

    private func formattedTotalValue(_ val: Double) -> String {
        switch habit.trackingStyle {
        case .duration:
            let minutes = Int(val)
            if minutes >= 60 {
                return "\(minutes / 60)h \(minutes % 60)m"
            }
            return "\(minutes) min"
        case .quantity:
            return "\(Int(val))"
        case .occurrence:
            return ""
        }
    }

    private func sentimentColor(for value: Double?) -> Color? {
        guard let value = value else { return nil }
        switch Int(value.rounded()) {
        case 1: return Color(hex: "#8E8E93")
        case 2: return Color(hex: "#AC8E68")
        case 3: return Color(hex: "#A2845E")
        case 4: return Color(hex: "#89AC76")
        case 5: return Color(hex: "#64A86B")
        case 6: return Color(hex: "#34C759")
        default: return nil
        }
    }
}

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    let entry: HabitEntry
    let habit: Habit
    let onSave: () -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var sentiment: Int?
    @State private var value: Double?
    @State private var note: String = ""
    @State private var entryDate: Date
    @State private var isSaving = false

    init(entry: HabitEntry, habit: Habit, onSave: @escaping () -> Void) {
        self.entry = entry
        self.habit = habit
        self.onSave = onSave
        _entryDate = State(initialValue: entry.timestamp)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Timestamp
                    DatePicker("Date & Time", selection: $entryDate, in: ...Date())

                    // Sentiment picker
                    SentimentPicker(selectedSentiment: $sentiment)

                    // Value input (if applicable)
                    if habit.trackingStyle != .occurrence {
                        valueInput
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.subheadline.bold())

                        TextField("Add a note...", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Entry")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(sentiment == nil || isSaving)
                    .bold()
                }
            }
            .onAppear {
                sentiment = entry.sentiment
                value = entry.value
                note = entry.note ?? ""
            }
        }
    }

    @ViewBuilder
    private var valueInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.trackingStyle == .duration ? "Duration" : "Quantity")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                Button {
                    let step: Double = habit.trackingStyle == .duration ? 5 : 1
                    value = max(0, (value ?? 0) - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text(formatValue(value ?? 0))
                    .font(.title3.monospacedDigit().bold())
                    .frame(minWidth: 60)

                Button {
                    let step: Double = habit.trackingStyle == .duration ? 5 : 1
                    value = (value ?? 0) + step
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func formatValue(_ val: Double) -> String {
        switch habit.trackingStyle {
        case .duration:
            let minutes = Int(val)
            if minutes >= 60 {
                return "\(minutes / 60)h \(minutes % 60)m"
            }
            return "\(minutes) min"
        case .quantity:
            return "\(Int(val))x"
        case .occurrence:
            return ""
        }
    }

    private func saveEntry() {
        guard let sentiment else { return }
        isSaving = true

        do {
            // Set fields directly to handle clearing values
            entry.sentiment = min(max(sentiment, 1), 6)
            entry.value = value
            entry.note = note.isEmpty ? nil : note

            try dependencies.entryRepository.update(entry, sentiment: sentiment, timestamp: entryDate)
            onSave()
            dismiss()
        } catch {
            print("Failed to save entry: \(error)")
            isSaving = false
        }
    }
}

// MARK: - Week Activity Widget

struct WeekActivityWidget: View {
    let data: [[HeatmapCell]]
    let habit: Habit

    @State private var selectedCell: HeatmapCell?

    private var cells: [HeatmapCell] {
        let all = data.flatMap { $0 }.sorted { $0.date < $1.date }
        return Array(all.suffix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(cells) { cell in
                    VStack(spacing: 6) {
                        Text(dayLabel(for: cell.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(cellColor(for: cell))
                            .frame(height: 48)
                            .overlay {
                                if cell.hasData, let sentiment = cell.averageSentiment {
                                    Text(sentimentEmojiFor(Int(sentiment.rounded())))
                                        .font(.title3)
                                }
                            }
                            .overlay(alignment: .top) {
                                if selectedCell?.id == cell.id {
                                    ActivityTooltip(cell: cell, habit: habit)
                                        .offset(y: -60)
                                }
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCell = selectedCell?.id == cell.id ? nil : cell
                                }
                            }

                        Text(cell.hasData ? "\(cell.entryCount)" : "–")
                            .font(.caption2)
                            .foregroundStyle(cell.hasData ? .primary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .zIndex(selectedCell?.id == cell.id ? 1 : 0)
                }
            }

            // Legend
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: habit.colorHex).opacity(0.2))
                    .frame(width: 8, height: 8)
                Text("No entry")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer().frame(width: 12)

                Circle()
                    .fill(Color(hex: habit.colorHex))
                    .frame(width: 8, height: 8)
                Text("Logged")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func cellColor(for cell: HeatmapCell) -> Color {
        guard cell.hasData else {
            return Color(hex: habit.colorHex).opacity(0.1)
        }
        guard let sentiment = cell.averageSentiment else {
            return Color(hex: habit.colorHex).opacity(0.3)
        }
        let intensity = (sentiment - 1) / 5.0
        return Color(hex: habit.colorHex).opacity(0.2 + intensity * 0.6)
    }
}

// MARK: - Activity Tooltip

struct ActivityTooltip: View {
    let cell: HeatmapCell
    let habit: Habit

    @Environment(\.colorScheme) private var colorScheme

    private var tooltipBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.96)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(cell.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(.secondary)

            if cell.hasData, let sentiment = cell.averageSentiment {
                HStack(spacing: 4) {
                    Text(sentimentEmojiFor(Int(sentiment.rounded())))
                        .font(.caption)
                    Text(String(format: "%.1f", sentiment))
                        .font(.caption.bold().monospacedDigit())
                }

                Text("\(cell.entryCount) entr\(cell.entryCount == 1 ? "y" : "ies")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let totalValue = cell.totalValue, totalValue > 0 {
                    Text(formattedTotal(totalValue))
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: habit.colorHex))
                }
            } else {
                Text("No entries")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(tooltipBackground)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .fixedSize()
    }

    private func formattedTotal(_ val: Double) -> String {
        switch habit.trackingStyle {
        case .duration:
            let minutes = Int(val)
            if minutes >= 60 {
                return "Total: \(minutes / 60)h \(minutes % 60)m"
            }
            return "Total: \(minutes) min"
        case .quantity:
            return "Total: \(Int(val))x"
        case .occurrence:
            return ""
        }
    }
}

// MARK: - Month Activity Widget

struct MonthActivityWidget: View {
    let title: String
    let data: [[HeatmapCell]]
    let habit: Habit

    @State private var selectedCell: HeatmapCell?

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(summaryText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Day-of-week header
            HStack(spacing: 3) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week rows
            VStack(spacing: 3) {
                ForEach(Array(data.enumerated()), id: \.offset) { weekIndex, week in
                    HStack(spacing: 3) {
                        ForEach(week) { cell in
                            monthCell(for: cell)
                                .zIndex(selectedCell?.id == cell.id ? 1 : 0)
                        }

                        // Pad incomplete weeks
                        if week.count < 7 {
                            ForEach(0..<(7 - week.count), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.clear)
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .zIndex(week.contains(where: { selectedCell?.id == $0.id }) ? 1 : 0)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func monthCell(for cell: HeatmapCell) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(for: cell))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if cell.hasData, let sentiment = cell.averageSentiment {
                    Text(sentimentEmojiFor(Int(sentiment.rounded())))
                        .font(.system(size: 14))
                        .minimumScaleFactor(0.4)
                }
            }
            .overlay(alignment: .top) {
                if selectedCell?.id == cell.id {
                    ActivityTooltip(cell: cell, habit: habit)
                        .offset(y: -60)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedCell = selectedCell?.id == cell.id ? nil : cell
                }
            }
    }

    private func cellColor(for cell: HeatmapCell) -> Color {
        guard cell.hasData else {
            return Color(hex: habit.colorHex).opacity(0.08)
        }
        guard let sentiment = cell.averageSentiment else {
            return Color(hex: habit.colorHex).opacity(0.3)
        }
        let intensity = (sentiment - 1) / 5.0
        return Color(hex: habit.colorHex).opacity(0.2 + intensity * 0.6)
    }

    private var summaryText: String {
        let allCells = data.flatMap { $0 }
        let activeDays = allCells.filter(\.hasData).count
        return "\(activeDays) active day\(activeDays == 1 ? "" : "s")"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color ?? .secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - All Entries View

struct AllEntriesView: View {
    let habit: Habit

    @Environment(\.dependencies) private var dependencies
    @State private var entries: [HabitEntry] = []
    @State private var groupedEntries: [(Date, [HabitEntry])] = []

    var body: some View {
        List {
            ForEach(groupedEntries, id: \.0) { date, dayEntries in
                Section {
                    ForEach(dayEntries) { entry in
                        HabitEntryRow(entry: entry)
                    }
                } header: {
                    Text(date, style: .date)
                }
            }
        }
        .navigationTitle("All Entries")
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        do {
            entries = try dependencies.entryRepository.fetchAll(for: habit)

            // Group by day
            let calendar = Calendar.current
            var grouped: [Date: [HabitEntry]] = [:]

            for entry in entries {
                let day = calendar.startOfDay(for: entry.timestamp)
                grouped[day, default: []].append(entry)
            }

            groupedEntries = grouped
                .sorted { $0.key > $1.key }
                .map { ($0.key, $0.value) }
        } catch {
            print("Failed to load entries: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Test Habit", icon: "star.fill", colorHex: "#FF9500"))
    }
    .withDependencies(.shared)
}
