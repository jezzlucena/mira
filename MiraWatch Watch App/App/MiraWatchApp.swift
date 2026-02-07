import SwiftUI
import SwiftData

@main
struct MiraWatchApp: App {
    @StateObject private var container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            WatchHabitListView()
                .withDependencies(container)
        }
    }
}
