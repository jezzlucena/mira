import SwiftUI

/// Onboarding flow introducing Mira's philosophy
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages = OnboardingPage.allPages

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }

                // Subscription page
                SubscriptionView(onSkip: {
                    withAnimation { currentPage = pages.count + 1 }
                })
                .tag(pages.count)

                // Final page: Create first habit
                CreateFirstHabitView(onComplete: completeOnboarding)
                    .tag(pages.count + 1)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(reduceMotion ? .none : .easeInOut, value: currentPage)

            // Page indicator and navigation
            VStack(spacing: 20) {
                PageIndicator(
                    currentPage: currentPage,
                    totalPages: pages.count + 2
                )

                if currentPage < pages.count {
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        GlassButton("Continue", icon: "arrow.right", style: .primary) {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func completeOnboarding() {
        do {
            try dependencies.preferencesRepository.completeOnboarding()
        } catch {
            // Log error but continue
            print("Failed to save onboarding status: \(error)")
        }
        onComplete()
    }
}

// MARK: - Onboarding Page Content

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            title: "Welcome to Mira",
            subtitle: "The Mirror, Not the Judge",
            description: "Mira helps you observe your habits without shame. No streaks. No guilt. Just awareness."
        ),
        OnboardingPage(
            icon: "face.smiling",
            title: "Every Log Includes Feeling",
            subtitle: "Correlate Behaviors with Emotions",
            description: "Each time you log a habit, you'll also note how you're feeling. This helps you discover patterns over time."
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Discover Your Patterns",
            subtitle: "Insights, Not Instructions",
            description: "Mira shows you correlations between your habits and mood. You decide what to do with that information."
        ),
        OnboardingPage(
            icon: "lock.shield",
            title: "Your Data, Your Control",
            subtitle: "Privacy First",
            description: "All data stays on your device by default. You can export it anytime. Cloud sync is optional."
        )
    ]
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle.bold())

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Page Indicator

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }
}

// MARK: - Create First Habit View

struct CreateFirstHabitView: View {
    let onComplete: () -> Void

    @Environment(\.dependencies) private var dependencies
    @State private var habitName = ""
    @State private var selectedIcon = "circle.fill"
    @State private var selectedColor = "#007AFF"
    @State private var isCreating = false
    @State private var showError = false

    private let suggestedHabits = [
        ("Water", "drop.fill", "#007AFF"),
        ("Exercise", "figure.run", "#34C759"),
        ("Sleep", "moon.fill", "#5856D6"),
        ("Reading", "book.fill", "#FF9500"),
        ("Meditation", "brain.head.profile", "#FF2D55")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Create Your First Habit")
                .font(.largeTitle.bold())

            Text("Start with something simple. You can add more later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Suggested habits
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Start")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestedHabits, id: \.0) { name, icon, color in
                            SuggestedHabitChip(
                                name: name,
                                icon: icon,
                                color: color,
                                isSelected: habitName == name
                            ) {
                                habitName = name
                                selectedIcon = icon
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Custom name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Or create your own")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("Habit name", text: $habitName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                GlassButton("Create Habit", icon: "plus", style: .large) {
                    createHabit()
                }
                .disabled(habitName.isEmpty || isCreating)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                Button("Skip for now") {
                    onComplete()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text("Failed to create habit. Please try again.")
        }
    }

    private func createHabit() {
        guard !habitName.isEmpty else { return }

        isCreating = true

        do {
            try dependencies.habitService.createHabit(
                name: habitName,
                icon: selectedIcon,
                colorHex: selectedColor
            )
            onComplete()
        } catch {
            showError = true
            isCreating = false
        }
    }
}

struct SuggestedHabitChip: View {
    let name: String
    let icon: String
    let color: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color(hex: color))
                Text(name)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(isSelected ? Color(hex: color).opacity(0.2) : .clear)
                    .glassEffect(.regular, in: .capsule)
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .strokeBorder(Color(hex: color), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
        .withDependencies(.shared)
}
