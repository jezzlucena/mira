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

    public lazy var subscriptionService: SubscriptionService = {
        SubscriptionService()
    }()

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

        // watchOS always uses CloudKit (depends on iPhone data) if premium.
        // iOS reads the user preference, gated on premium subscription.
        #if os(watchOS)
        let wantsCloudKit = SubscriptionService.cachedIsPremium
        #else
        let iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        let wantsCloudKit = iCloudSyncEnabled && SubscriptionService.cachedIsPremium
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
            } else if UserDefaults.standard.bool(forKey: "storeResetApproved") {
                // User explicitly approved the store reset — safe to delete.
                UserDefaults.standard.removeObject(forKey: "storeResetApproved")

                let storeURL = cloudConfig.url
                let dir = storeURL.deletingLastPathComponent()
                let storeName = storeURL.deletingPathExtension().lastPathComponent
                for suffix in ["", "-shm", "-wal"] {
                    let fileURL = dir.appendingPathComponent(storeName + ".store" + suffix)
                    try? FileManager.default.removeItem(at: fileURL)
                }

                if let container = try? ModelContainer(
                    for: schema,
                    configurations: [cloudConfig]
                ) {
                    self.modelContainer = container
                    self.cloudKitState = .connected
                } else {
                    // Store reset failed — fall back to local-only so we don't crash.
                    UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
                    let fallbackConfig = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        allowsSave: true,
                        cloudKitDatabase: .none
                    )
                    self.modelContainer = try! ModelContainer(
                        for: schema,
                        configurations: [fallbackConfig]
                    )
                    self.cloudKitState = .unavailable
                }
            } else {
                // Existing local store is incompatible with CloudKit.
                // Fall back to local-only storage to preserve user data.
                // The UI will prompt the user before any deletion happens.
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )

                do {
                    self.modelContainer = try ModelContainer(
                        for: schema,
                        configurations: [localConfig]
                    )
                    self.cloudKitState = .migrationRequired
                } catch {
                    fatalError("Failed to create fallback ModelContainer: \(error)")
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

                #if !os(watchOS)
                // User wants sync but isn't premium
                if iCloudSyncEnabled && !SubscriptionService.cachedIsPremium {
                    self.cloudKitState = .subscriptionRequired
                } else {
                    self.cloudKitState = .off
                }
                #else
                self.cloudKitState = .off
                #endif
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    /// Approves the store reset required for CloudKit migration.
    /// The actual deletion happens on the next app launch.
    public func approveStoreResetForCloudKit() {
        UserDefaults.standard.set(true, forKey: "storeResetApproved")
    }

    /// Cancels the pending CloudKit migration and reverts to local-only mode.
    public func cancelCloudKitMigration() {
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
        UserDefaults.standard.removeObject(forKey: "storeResetApproved")
        cloudKitState = .off
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
    /// Local store is incompatible with CloudKit — user must approve reset
    case migrationRequired
    /// User enabled sync but does not have a premium subscription
    case subscriptionRequired
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
            .environmentObject(container.subscriptionService)
            .modelContainer(container.modelContainer)
    }
}
