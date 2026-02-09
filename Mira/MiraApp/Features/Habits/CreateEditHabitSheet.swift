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
    @State private var customColor: Color = .blue

    private let presetColors = [
        // Reds & Warm
        "#FF3B30", // Red
        "#FF6B6B", // Coral
        "#FF9500", // Orange
        "#FFCC00", // Amber
        "#FFD60A", // Yellow
        // Greens & Cool
        "#A8D848", // Lime
        "#34C759", // Green
        "#30D158", // Mint
        "#00C7BE", // Teal
        "#64D2FF", // Sky
        // Blues & Purples
        "#007AFF", // Blue
        "#5856D6", // Indigo
        "#AF52DE", // Purple
        "#BF5AF2", // Violet
        "#FF2D55", // Pink
        // Earth & Neutral
        "#FF6482", // Rose
        "#A2845E", // Brown
        "#8E8E93", // Gray
        "#636366", // Graphite
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
                        ForEach(presetColors, id: \.self) { color in
                            ColorButton(
                                color: color,
                                isSelected: selectedColor == color
                            ) {
                                selectedColor = color
                            }
                        }

                        // Custom color swatch
                        CustomColorSwatch(
                            color: customColor,
                            isSelected: !presetColors.contains(selectedColor)
                        ) {
                            selectedColor = customColor.toHex()
                        }
                    }
                    .padding(.vertical, 8)

                    // Inline color picker (shown when custom is active)
                    if !presetColors.contains(selectedColor) {
                        ColorPicker("Pick a color", selection: $customColor, supportsOpacity: false)
                            .onChange(of: customColor) { _, newColor in
                                selectedColor = newColor.toHex()
                            }
                    }
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
                    // If editing a habit with a custom color, sync the picker
                    if !presetColors.contains(habit.colorHex) {
                        customColor = Color(hex: habit.colorHex)
                    }
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

// MARK: - Custom Color Swatch

private struct CustomColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                    )
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Selected custom color" : "Custom color picker")
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
