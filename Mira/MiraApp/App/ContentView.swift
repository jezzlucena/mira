import SwiftUI

/// Main content view with adaptive layout
/// - iPhone: Tab-based navigation
/// - iPad/Mac: Three-column NavigationSplitView
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: Tab = .dashboard
    @State private var selectedHabit: Habit?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        if horizontalSizeClass == .compact {
            compactLayout
        } else {
            regularLayout
        }
    }

    // MARK: - iPhone Layout (Compact)

    @ViewBuilder
    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "sun.horizon.fill")
                }
                .tag(Tab.dashboard)

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "list.bullet")
                }
                .tag(Tab.habits)

            AnalyticsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }
                .tag(Tab.analytics)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
    }

    // MARK: - iPad/Mac Layout (Regular)

    @ViewBuilder
    private var regularLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarView(
                selectedTab: $selectedTab,
                selectedHabit: $selectedHabit
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            // Content column
            contentColumn
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        } detail: {
            // Detail column
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .habits:
            HabitsListView(selectedHabit: $selectedHabit)
        case .analytics:
            AnalyticsOverviewView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let habit = selectedHabit {
            HabitDetailView(habit: habit)
        } else {
            ContentUnavailableView(
                "Select a Habit",
                systemImage: "hand.tap",
                description: Text("Choose a habit from the list to see details")
            )
        }
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable, Identifiable {
    case dashboard
    case habits
    case analytics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Today"
        case .habits: return "Habits"
        case .analytics: return "Insights"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "sun.horizon.fill"
        case .habits: return "list.bullet"
        case .analytics: return "chart.xyaxis.line"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Sidebar View (iPad/Mac)

struct SidebarView: View {
    @Binding var selectedTab: Tab
    @Binding var selectedHabit: Habit?
    @Environment(\.dependencies) private var dependencies
    @State private var habits: [Habit] = []

    var body: some View {
        List {
            Section {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .listItemTint(selectedTab == tab ? .accentColor : nil)
                }
            }

            Section("Quick Access") {
                ForEach(habits.prefix(5)) { habit in
                    Button {
                        selectedTab = .habits
                        selectedHabit = habit
                    } label: {
                        Label {
                            Text(habit.name)
                        } icon: {
                            Image(systemName: habit.icon)
                                .foregroundStyle(Color(hex: habit.colorHex))
                        }
                    }
                }
            }
        }
        .navigationTitle("Mira")
        .task {
            await loadHabits()
        }
    }

    private func loadHabits() async {
        do {
            habits = try dependencies.habitRepository.fetchAll()
        } catch {
            habits = []
        }
    }
}

// MARK: - Preview

#Preview("iPhone") {
    ContentView()
        .withDependencies(.shared)
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad") {
    ContentView()
        .withDependencies(.shared)
        .environment(\.horizontalSizeClass, .regular)
}
