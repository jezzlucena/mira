import Combine
import Foundation
import SwiftData
import SwiftUI

/// Central dependency container for the Mira app
/// Manages SwiftData configuration and service instances
@MainActor
public final class DependencyContainer: ObservableObject {
    // MARK: - Shared Instance

    public static let shared = DependencyContainer()

    // MARK: - SwiftData

    public let modelContainer: ModelContainer
    public var modelContext: ModelContext {
        modelContainer.mainContext
    }

    /// Current iCloud sync state
    @Published public private(set) var cloudKitState: CloudKitState = .off

    // MARK: - Services

    public lazy var habitService: HabitService = {
        HabitService(modelContext: modelContext)
    }()

    #if !os(watchOS)
    public lazy var analyticsEngine: AnalyticsEngine = {
        AnalyticsEngine(modelContext: modelContext)
    }()

    public lazy var healthKitManager: HealthKitManager = {
        HealthKitManager()
    }()

    public lazy var exportService: ExportService = {
        ExportService(modelContext: modelContext)
    }()
    #endif

    // MARK: - Repositories

    public lazy var habitRepository: HabitRepository = {
        HabitRepository(modelContext: modelContext)
    }()

    public lazy var entryRepository: EntryRepository = {
        EntryRepository(modelContext: modelContext)
    }()

    public lazy var sentimentRepository: SentimentRepository = {
        SentimentRepository(modelContext: modelContext)
    }()

    public lazy var preferencesRepository: PreferencesRepository = {
        PreferencesRepository(modelContext: modelContext)
    }()

    // MARK: - Initialization

    private init() {
        let schema = Schema([
            Habit.self,
            HabitEntry.self,
            SentimentRecord.self,
            UserPreferences.self
        ])

        // watchOS always uses CloudKit (depends on iPhone data).
        // iOS reads the user preference.
        #if os(watchOS)
        let wantsCloudKit = true
        #else
        let wantsCloudKit = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        #endif

        if wantsCloudKit {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .automatic
            )

            if let container = try? ModelContainer(
                for: schema,
                configurations: [cloudConfig]
            ) {
                self.modelContainer = container
                self.cloudKitState = .connected
            } else {
                // Existing local store is incompatible with CloudKit.
                // Delete it and create a fresh CloudKit-enabled store.
                let storeURL = cloudConfig.url
                let dir = storeURL.deletingLastPathComponent()
                let storeName = storeURL.deletingPathExtension().lastPathComponent
                for suffix in ["", "-shm", "-wal"] {
                    let fileURL = dir.appendingPathComponent(storeName + ".store" + suffix)
                    try? FileManager.default.removeItem(at: fileURL)
                }

                do {
                    self.modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [cloudConfig]
                    )
                    self.cloudKitState = .connected
                } catch {
                    fatalError("Failed to create CloudKit ModelContainer after store reset: \(error)")
                }
            }
        } else {
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                self.modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [localConfig]
                )
                self.cloudKitState = .off
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    /// Creates a container for testing with in-memory storage
    public static func forTesting() -> DependencyContainer {
        DependencyContainer(inMemory: true)
    }

    private init(inMemory: Bool) {
        do {
            let schema = Schema([
                Habit.self,
                HabitEntry.self,
                SentimentRecord.self,
                UserPreferences.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}

// MARK: - CloudKit State

public enum CloudKitState {
    /// User has not enabled iCloud sync
    case off
    /// iCloud sync is active and working
    case connected
    /// User enabled sync but CloudKit setup failed (container not configured)
    case unavailable
}

// MARK: - SwiftUI Environment Integration

private struct DependencyContainerKey: EnvironmentKey {
    @MainActor static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    public var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access

extension View {
    public func withDependencies(_ container: DependencyContainer) -> some View {
        self
            .environment(\.dependencies, container)
            .modelContainer(container.modelContainer)
    }
}
