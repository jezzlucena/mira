import SwiftUI
import SwiftData
import StoreKit

@main
struct MiraWatchApp: App {
    @StateObject private var container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView(subscriptionService: container.subscriptionService)
                .withDependencies(container)
        }
    }
}

private struct WatchContentView: View {
    @ObservedObject var subscriptionService: SubscriptionService

    var body: some View {
        if subscriptionService.isPremium {
            WatchHabitListView()
        } else {
            WatchSubscriptionGateView()
                .task {
                    // Sync with the App Store to pick up subscriptions
                    // purchased on the iPhone
                    try? await AppStore.sync()
                    await subscriptionService.refreshSubscriptionStatus()
                }
        }
    }
}
