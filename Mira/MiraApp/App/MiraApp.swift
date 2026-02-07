import SwiftUI
import SwiftData

/// Mira - A harm-reduction focused habit tracker
/// "The Mirror, Not the Judge"
@main
struct MiraApp: App {
    @StateObject private var container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .withDependencies(container)
        }
    }
}

/// Root view that handles onboarding state
struct RootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var hasCompletedOnboarding = false
    @State private var isCheckingOnboarding = true

    var body: some View {
        Group {
            if isCheckingOnboarding {
                // Loading state
                ProgressView()
            } else if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                })
            }
        }
        .task {
            await checkOnboardingStatus()
        }
    }

    private func checkOnboardingStatus() async {
        do {
            let prefs = try dependencies.preferencesRepository.get()
            hasCompletedOnboarding = prefs.hasCompletedOnboarding
        } catch {
            // If we can't read preferences, assume first launch
            hasCompletedOnboarding = false
        }
        isCheckingOnboarding = false
    }
}
