import Combine
import Foundation
import SwiftData

/// Repository for UserPreferences management
/// Ensures only one preferences record exists
@MainActor
public final class PreferencesRepository: ObservableObject {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Read

    /// Gets the current user preferences, creating default if none exist
    public func get() throws -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        let existing = try modelContext.fetch(descriptor)

        if let preferences = existing.first {
            return preferences
        }

        // Create default preferences
        let preferences = UserPreferences(firstOpenDate: Date())
        modelContext.insert(preferences)
        try modelContext.save()
        return preferences
    }

    // MARK: - Update

    /// Updates user preferences
    public func update(_ updates: (inout UserPreferences) -> Void) throws {
        var preferences = try get()
        updates(&preferences)
        try modelContext.save()
    }

    /// Marks onboarding as complete
    public func completeOnboarding() throws {
        let preferences = try get()
        preferences.hasCompletedOnboarding = true
        try modelContext.save()
    }

    /// Updates accessibility settings
    public func updateAccessibility(
        disableHaptics: Bool? = nil,
        reduceMotion: Bool? = nil,
        highContrast: Bool? = nil,
        useDyslexiaFont: Bool? = nil
    ) throws {
        let preferences = try get()

        if let disableHaptics = disableHaptics {
            preferences.disableHaptics = disableHaptics
        }
        if let reduceMotion = reduceMotion {
            preferences.reduceMotion = reduceMotion
        }
        if let highContrast = highContrast {
            preferences.highContrast = highContrast
        }
        if let useDyslexiaFont = useDyslexiaFont {
            preferences.useDyslexiaFont = useDyslexiaFont
        }

        try modelContext.save()
    }

    /// Updates privacy settings
    public func updatePrivacy(
        requireAuthentication: Bool? = nil,
        hideInAppSwitcher: Bool? = nil,
        healthKitEnabled: Bool? = nil
    ) throws {
        let preferences = try get()

        if let requireAuthentication = requireAuthentication {
            preferences.requireAuthentication = requireAuthentication
        }
        if let hideInAppSwitcher = hideInAppSwitcher {
            preferences.hideInAppSwitcher = hideInAppSwitcher
        }
        if let healthKitEnabled = healthKitEnabled {
            preferences.healthKitEnabled = healthKitEnabled
        }

        try modelContext.save()
    }

    /// Updates notification settings
    public func updateNotifications(
        enabled: Bool? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil
    ) throws {
        let preferences = try get()

        if let enabled = enabled {
            preferences.notificationsEnabled = enabled
        }
        if let reminderHour = reminderHour {
            preferences.defaultReminderHour = reminderHour
        }
        if let reminderMinute = reminderMinute {
            preferences.defaultReminderMinute = reminderMinute
        }

        try modelContext.save()
    }

    /// Updates sync timestamp
    public func updateLastSync(_ date: Date) throws {
        let preferences = try get()
        preferences.lastSyncDate = date
        try modelContext.save()
    }

    /// Toggles cloud sync (paid feature)
    public func setCloudSync(enabled: Bool) throws {
        let preferences = try get()
        preferences.cloudSyncEnabled = enabled
        try modelContext.save()
    }

    // MARK: - Reset

    /// Resets all preferences to defaults (keeps firstOpenDate)
    public func resetToDefaults() throws {
        let preferences = try get()
        let firstOpen = preferences.firstOpenDate

        // Reset to defaults
        preferences.disableHaptics = false
        preferences.reduceMotion = false
        preferences.highContrast = false
        preferences.useDyslexiaFont = false
        preferences.requireAuthentication = false
        preferences.hideInAppSwitcher = false
        preferences.healthKitEnabled = false
        preferences.notificationsEnabled = false
        preferences.defaultReminderHour = 20
        preferences.defaultReminderMinute = 0
        preferences.preferredColorSchemeRaw = nil
        preferences.showCompletedOnDashboard = true
        preferences.firstOpenDate = firstOpen
        preferences.cloudSyncEnabled = false

        try modelContext.save()
    }
}
