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
    @State private var showMigrationAlert = false
    @State private var showMigrationRestartAlert = false

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
        .onAppear {
            if dependencies.cloudKitState == .migrationRequired {
                showMigrationAlert = true
            }
        }
        .alert("iCloud Sync Requires Data Reset", isPresented: $showMigrationAlert) {
            Button("Cancel — Keep Local Data", role: .cancel) {
                dependencies.cancelCloudKitMigration()
            }
            Button("Erase Local Data & Enable Sync", role: .destructive) {
                dependencies.approveStoreResetForCloudKit()
                showMigrationRestartAlert = true
            }
        } message: {
            Text("Your local database is not compatible with iCloud sync. Enabling sync requires erasing local data.\n\nWe strongly recommend exporting your data from Settings first. Tap Cancel to go back and export.")
        }
        .alert("Restart Required", isPresented: $showMigrationRestartAlert) {
            Button("OK") {}
        } message: {
            Text("Please restart Mira to complete the iCloud sync setup.")
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
