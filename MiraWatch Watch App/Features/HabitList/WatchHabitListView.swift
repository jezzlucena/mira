import SwiftUI
import SwiftData

/// Main watch screen: today's habits split into unlogged and logged sections
struct WatchHabitListView: View {
    @Query(filter: #Predicate<Habit> { !$0.isArchived },
           sort: \Habit.displayOrder)
    private var habits: [Habit]

    private var unloggedHabits: [Habit] {
        habits.filter { !$0.isLoggedToday }
    }

    private var loggedHabits: [Habit] {
        habits.filter { $0.isLoggedToday }
    }

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView {
                        Label("No Habits", systemImage: "list.bullet")
                    } description: {
                        Text("Please make sure iCloud Sync is enabled on your iOS app.")
                    }
                } else {
                    List {
                        if !unloggedHabits.isEmpty {
                            Section("To Log") {
                                ForEach(unloggedHabits) { habit in
                                    NavigationLink(value: WatchDestination.logFlow(habit)) {
                                        WatchHabitRow(habit: habit, isLogged: false)
                                    }
                                }
                            }
                        }

                        if !loggedHabits.isEmpty {
                            Section("Logged") {
                                ForEach(loggedHabits) { habit in
                                    NavigationLink(value: WatchDestination.entryList(habit)) {
                                        WatchHabitRow(habit: habit, isLogged: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mira")
            .navigationDestination(for: WatchDestination.self) { destination in
                switch destination {
                case .logFlow(let habit):
                    WatchLogFlow(habit: habit)
                case .entryList(let habit):
                    WatchEntryListView(habit: habit)
                }
            }
        }
    }
}

// MARK: - Navigation Destinations

enum WatchDestination: Hashable {
    case logFlow(Habit)
    case entryList(Habit)

    static func == (lhs: WatchDestination, rhs: WatchDestination) -> Bool {
        switch (lhs, rhs) {
        case (.logFlow(let a), .logFlow(let b)): return a.id == b.id
        case (.entryList(let a), .entryList(let b)): return a.id == b.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .logFlow(let habit):
            hasher.combine("logFlow")
            hasher.combine(habit.id)
        case .entryList(let habit):
            hasher.combine("entryList")
            hasher.combine(habit.id)
        }
    }
}
