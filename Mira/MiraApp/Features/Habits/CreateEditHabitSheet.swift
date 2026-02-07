import SwiftUI

/// Sheet for creating or editing a habit
struct CreateEditHabitSheet: View {
    enum Mode {
        case create
        case edit(Habit)

        var title: String {
            switch self {
            case .create: return "New Habit"
            case .edit: return "Edit Habit"
            }
        }
    }

    let mode: Mode
    let onSave: (Habit) -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "circle.fill"
    @State private var selectedColor: String = "#007AFF"
    @State private var trackingStyle: TrackingStyle = .occurrence
    @State private var isLocalOnly: Bool = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var showIconPicker = false

    private let colors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF2D55", // Pink
        "#5856D6", // Purple
        "#AF52DE", // Violet
        "#00C7BE", // Teal
        "#FF3B30", // Red
        "#8E8E93", // Gray
    ]

    private let icons = [
        "circle.fill", "heart.fill", "star.fill", "bolt.fill",
        "drop.fill", "flame.fill", "leaf.fill", "moon.fill",
        "sun.max.fill", "cloud.fill", "snowflake", "wind",
        "figure.run", "figure.walk", "figure.mind.and.body", "dumbbell.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "pills.fill",
        "book.fill", "pencil", "music.note", "gamecontroller.fill",
        "phone.fill", "laptopcomputer", "tv.fill", "bed.double.fill",
        "shower.fill", "face.smiling", "brain.head.profile", "eye.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section {
                    TextField("Habit name", text: $name)
                } header: {
                    Text("Name")
                }

                // Icon
                Section {
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundStyle(Color(hex: selectedColor))
                                .frame(width: 44, height: 44)
                                .background {
                                    Circle()
                                        .fill(Color(hex: selectedColor).opacity(0.15))
                                }

                            Text("Choose icon")
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Icon")
                }

                // Color
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            ColorButton(
                                color: color,
                                isSelected: selectedColor == color
                            ) {
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                // Tracking style
                Section {
                    Picker("Tracking Style", selection: $trackingStyle) {
                        ForEach(TrackingStyle.allCases) { style in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(style.displayName)
                                    Text(style.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: style.icon)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("How to Track")
                } footer: {
                    Text(trackingStyleFooter)
                }

                // Privacy
                Section {
                    Toggle("Keep Local Only", isOn: $isLocalOnly)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Local-only habits will never sync to the cloud, even if you enable sync.")
                }
            }
            .navigationTitle(mode.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(
                    selectedIcon: $selectedIcon,
                    icons: icons,
                    color: selectedColor
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text("Failed to save habit. Please try again.")
            }
            .onAppear {
                if case .edit(let habit) = mode {
                    name = habit.name
                    selectedIcon = habit.icon
                    selectedColor = habit.colorHex
                    trackingStyle = habit.trackingStyle
                    isLocalOnly = habit.isLocalOnly
                }
            }
        }
    }

    private var trackingStyleFooter: String {
        switch trackingStyle {
        case .occurrence:
            return "Simply log when this habit occurs. Good for things like 'took medication'."
        case .duration:
            return "Log how long you spent on this habit. Good for meditation, exercise, etc."
        case .quantity:
            return "Log a count each time. Good for glasses of water, cigarettes, etc."
        }
    }

    private func saveHabit() {
        guard !name.isEmpty else { return }

        isSaving = true

        do {
            switch mode {
            case .create:
                let habit = try dependencies.habitService.createHabit(
                    name: name,
                    icon: selectedIcon,
                    colorHex: selectedColor,
                    trackingStyle: trackingStyle,
                    isLocalOnly: isLocalOnly
                )
                onSave(habit)

            case .edit(let habit):
                try dependencies.habitRepository.update(
                    habit,
                    name: name,
                    icon: selectedIcon,
                    colorHex: selectedColor,
                    trackingStyle: trackingStyle,
                    isLocalOnly: isLocalOnly
                )
                onSave(habit)
            }

            dismiss()
        } catch {
            showError = true
            isSaving = false
        }
    }
}

// MARK: - Color Button

private struct ColorButton: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 40, height: 40)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Selected color" : "Color option")
    }
}

// MARK: - Icon Picker Sheet

struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    let icons: [String]
    let color: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(Color(hex: color))
                                .frame(width: 50, height: 50)
                                .background {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: color).opacity(0.2) : .clear)
                                }
                                .overlay {
                                    if selectedIcon == icon {
                                        Circle()
                                            .strokeBorder(Color(hex: color), lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    CreateEditHabitSheet(mode: .create) { _ in }
        .withDependencies(.shared)
}
