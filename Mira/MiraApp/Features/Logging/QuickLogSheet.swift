import SwiftUI

/// Quick log sheet for fast 2-tap logging
struct QuickLogSheet: View {
    let habit: Habit?
    let onComplete: () -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHabit: Habit?
    @State private var selectedSentiment: Int?
    @State private var value: Double?
    @State private var note: String = ""
    @State private var habits: [Habit] = []
    @State private var step: LogStep = .selectHabit
    @State private var isSaving = false
    @State private var showError = false

    private enum LogStep {
        case selectHabit
        case selectSentiment
        case addDetails
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress indicator
                progressIndicator

                // Content based on step
                switch step {
                case .selectHabit:
                    habitSelectionView
                case .selectSentiment:
                    sentimentSelectionView
                case .addDetails:
                    detailsView
                }

                Spacer()
            }
            .padding()
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if step == .addDetails {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveEntry()
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text("Failed to save entry. Please try again.")
            }
            .task {
                await loadHabits()
                // If habit was pre-selected, skip to sentiment
                if let habit = habit {
                    selectedHabit = habit
                    step = .selectSentiment
                }
            }
        }
    }

    // MARK: - Progress Indicator

    @ViewBuilder
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(stepIndex >= index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.top)
    }

    private var stepIndex: Int {
        switch step {
        case .selectHabit: return 0
        case .selectSentiment: return 1
        case .addDetails: return 2
        }
    }

    // MARK: - Habit Selection

    @ViewBuilder
    private var habitSelectionView: some View {
        VStack(spacing: 16) {
            Text("What did you do?")
                .font(.title2.bold())

            if habits.isEmpty {
                ContentUnavailableView(
                    "No Habits",
                    systemImage: "list.bullet",
                    description: Text("Create a habit first")
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(habits) { habit in
                        HabitSelectionCard(
                            habit: habit,
                            isSelected: selectedHabit?.id == habit.id
                        ) {
                            selectedHabit = habit
                            withAnimation {
                                step = .selectSentiment
                            }
                        }
                    }
                }
            }

            // Standalone mood log option
            Button {
                selectedHabit = nil
                withAnimation {
                    step = .selectSentiment
                }
            } label: {
                HStack {
                    Image(systemName: "face.smiling")
                    Text("Just log my mood")
                }
                .foregroundStyle(.secondary)
            }
            .padding(.top)
        }
    }

    // MARK: - Sentiment Selection

    @ViewBuilder
    private var sentimentSelectionView: some View {
        VStack(spacing: 24) {
            if let habit = selectedHabit {
                HStack(spacing: 12) {
                    Image(systemName: habit.icon)
                        .font(.title)
                        .foregroundStyle(Color(hex: habit.colorHex))

                    Text(habit.name)
                        .font(.title2.bold())
                }
            } else {
                Text("How are you feeling?")
                    .font(.title2.bold())
            }

            SentimentPicker(selectedSentiment: $selectedSentiment) { _ in
                // Auto-advance after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        step = .addDetails
                    }
                }
            }

            // Value input for duration/quantity habits
            if let habit = selectedHabit, habit.trackingStyle != .occurrence {
                valueInputView(for: habit)
            }
        }
    }

    @ViewBuilder
    private func valueInputView(for habit: Habit) -> some View {
        VStack(spacing: 8) {
            Text(habit.trackingStyle == .duration ? "How long?" : "How many?")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    value = (value ?? 0) - (habit.trackingStyle == .duration ? 5 : 1)
                    if let v = value, v < 0 { value = 0 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                .disabled((value ?? 0) <= 0)

                Text("\(Int(value ?? 0))")
                    .font(.largeTitle.monospacedDigit())
                    .frame(width: 80)

                Button {
                    value = (value ?? 0) + (habit.trackingStyle == .duration ? 5 : 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
            }

            if let unit = habit.trackingStyle.unitLabel {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Details View

    @ViewBuilder
    private var detailsView: some View {
        VStack(spacing: 20) {
            // Summary
            HStack(spacing: 16) {
                if let habit = selectedHabit {
                    Image(systemName: habit.icon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: habit.colorHex))
                } else {
                    Image(systemName: "face.smiling")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedHabit?.name ?? "Mood Check-in")
                        .font(.headline)

                    if let sentiment = selectedSentiment {
                        HStack(spacing: 4) {
                            SentimentBadge(sentiment: sentiment)
                            Text(sentimentLabel(for: sentiment))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Edit sentiment button
                Button {
                    withAnimation {
                        step = .selectSentiment
                    }
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title2)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }

            // Optional note
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a note (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("What's on your mind?", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }

            // Quick save button
            GlassButton("Save Entry", icon: "checkmark", style: .large) {
                saveEntry()
            }
            .disabled(selectedSentiment == nil || isSaving)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Navigation

    private var navigationTitle: String {
        switch step {
        case .selectHabit: return "Log Entry"
        case .selectSentiment: return "How do you feel?"
        case .addDetails: return "Add Details"
        }
    }

    // MARK: - Helpers

    private func sentimentLabel(for value: Int) -> String {
        switch value {
        case 1: return "Awful"
        case 2: return "Rough"
        case 3: return "Meh"
        case 4: return "Okay"
        case 5: return "Good"
        case 6: return "Great"
        default: return ""
        }
    }

    private func loadHabits() async {
        do {
            habits = try dependencies.habitRepository.fetchAll()
        } catch {
            habits = []
        }
    }

    private func saveEntry() {
        guard let sentiment = selectedSentiment else { return }

        isSaving = true

        do {
            if let habit = selectedHabit {
                // Log habit entry
                try dependencies.habitService.logEntry(
                    for: habit,
                    sentiment: sentiment,
                    value: value,
                    note: note.isEmpty ? nil : note
                )
            } else {
                // Log standalone sentiment
                try dependencies.sentimentRepository.create(
                    sentiment: sentiment,
                    note: note.isEmpty ? nil : note
                )
            }
            onComplete()
        } catch {
            showError = true
            isSaving = false
        }
    }
}

// MARK: - Habit Selection Card

struct HabitSelectionCard: View {
    let habit: Habit
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: habit.icon)
                    .font(.title)
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 56, height: 56)
                    .background {
                        Circle()
                            .fill(isSelected ? Color(hex: habit.colorHex).opacity(0.2) : .clear)
                            .glassEffect(.regular, in: .circle)
                    }
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Color(hex: habit.colorHex), lineWidth: 2)
                        }
                    }

                Text(habit.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 100)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    QuickLogSheet(habit: nil, onComplete: {})
        .withDependencies(.shared)
}
