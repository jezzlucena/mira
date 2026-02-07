import SwiftUI

/// Habits tab showing all habits with create/edit functionality
struct HabitsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var habits: [Habit] = []
    @State private var archivedHabits: [Habit] = []
    @State private var showCreateSheet = false
    @State private var selectedHabit: Habit?
    @State private var showArchived = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty && !isLoading {
                    emptyState
                } else {
                    // Active habits
                    Section {
                        ForEach(habits) { habit in
                            HabitListRow(habit: habit) {
                                selectedHabit = habit
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    archiveHabit(habit)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                            }
                        }
                        .onMove { from, to in
                            reorderHabits(from: from, to: to)
                        }
                    }

                    // Archived section
                    if !archivedHabits.isEmpty {
                        Section {
                            DisclosureGroup("Archived (\(archivedHabits.count))", isExpanded: $showArchived) {
                                ForEach(archivedHabits) { habit in
                                    HabitListRow(habit: habit) {
                                        selectedHabit = habit
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            unarchiveHabit(habit)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteHabit(habit)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            unarchiveHabit(habit)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }

                                        Button(role: .destructive) {
                                            deleteHabit(habit)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                #endif
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateEditHabitSheet(
                    mode: .create,
                    onSave: { _ in
                        Task { await loadHabits() }
                    }
                )
            }
            .sheet(item: $selectedHabit) { habit in
                NavigationStack {
                    HabitDetailView(habit: habit)
                }
            }
            .refreshable {
                await loadHabits()
            }
            .task {
                await loadHabits()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Habits", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Create your first habit to start tracking")
        } actions: {
            Button("Create Habit") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func loadHabits() async {
        isLoading = true
        defer { isLoading = false }

        do {
            habits = try dependencies.habitRepository.fetchAll()
            archivedHabits = try dependencies.habitRepository.fetchArchived()
        } catch {
            print("Failed to load habits: \(error)")
        }
    }

    private func archiveHabit(_ habit: Habit) {
        do {
            try dependencies.habitRepository.archive(habit)
            Task { await loadHabits() }
        } catch {
            print("Failed to archive: \(error)")
        }
    }

    private func unarchiveHabit(_ habit: Habit) {
        do {
            try dependencies.habitRepository.unarchive(habit)
            Task { await loadHabits() }
        } catch {
            print("Failed to unarchive: \(error)")
        }
    }

    private func deleteHabit(_ habit: Habit) {
        do {
            try dependencies.habitRepository.delete(habit)
            Task { await loadHabits() }
        } catch {
            print("Failed to delete: \(error)")
        }
    }

    private func reorderHabits(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        do {
            try dependencies.habitRepository.updateOrder(habits)
        } catch {
            print("Failed to reorder: \(error)")
        }
    }
}

// MARK: - Habits List View (for iPad split view)

struct HabitsListView: View {
    @Binding var selectedHabit: Habit?
    @Environment(\.dependencies) private var dependencies
    @State private var habits: [Habit] = []
    @State private var showCreateSheet = false

    var body: some View {
        List(selection: $selectedHabit) {
            ForEach(habits) { habit in
                NavigationLink(value: habit) {
                    HStack(spacing: 12) {
                        Image(systemName: habit.icon)
                            .foregroundStyle(Color(hex: habit.colorHex))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.name)
                                .font(.headline)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .tag(habit)
            }
        }
        .navigationTitle("Habits")
        .toolbar {
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateEditHabitSheet(mode: .create) { _ in
                Task { await loadHabits() }
            }
        }
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

#Preview {
    HabitsView()
        .withDependencies(.shared)
}
