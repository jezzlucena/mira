import Foundation
import SwiftData

/// User preferences and settings
/// Stored in SwiftData for persistence and potential cloud sync
@Model
public final class UserPreferences {
    /// Unique identifier (should only be one record per user)
    public var id: UUID = UUID()

    // MARK: - Accessibility

    /// Disable haptic feedback
    public var disableHaptics: Bool = false

    /// Reduce motion/animations
    public var reduceMotion: Bool = false

    /// High contrast mode
    public var highContrast: Bool = false

    /// Use dyslexia-friendly font
    public var useDyslexiaFont: Bool = false

    // MARK: - Privacy

    /// Require biometric/passcode to open app
    public var requireAuthentication: Bool = false

    /// Hide app content in app switcher
    public var hideInAppSwitcher: Bool = false

    /// Enable HealthKit integration
    public var healthKitEnabled: Bool = false

    // MARK: - Notifications

    /// Enable reminder notifications
    public var notificationsEnabled: Bool = false

    /// Default reminder time (stored as hour and minute)
    public var defaultReminderHour: Int = 20
    public var defaultReminderMinute: Int = 0

    // MARK: - Display

    /// Preferred color scheme (nil = system default)
    public var preferredColorSchemeRaw: String?

    /// Show completed habits on dashboard
    public var showCompletedOnDashboard: Bool = true

    // MARK: - Onboarding

    /// Whether user has completed onboarding
    public var hasCompletedOnboarding: Bool = false

    /// When user first opened the app
    public var firstOpenDate: Date?

    // MARK: - Sync

    /// Last successful sync timestamp
    public var lastSyncDate: Date?

    /// Whether cloud sync is enabled (paid feature)
    public var cloudSyncEnabled: Bool = false

    public init(
        id: UUID = UUID(),
        disableHaptics: Bool = false,
        reduceMotion: Bool = false,
        highContrast: Bool = false,
        useDyslexiaFont: Bool = false,
        requireAuthentication: Bool = false,
        hideInAppSwitcher: Bool = false,
        healthKitEnabled: Bool = false,
        notificationsEnabled: Bool = false,
        defaultReminderHour: Int = 20,
        defaultReminderMinute: Int = 0,
        preferredColorSchemeRaw: String? = nil,
        showCompletedOnDashboard: Bool = true,
        hasCompletedOnboarding: Bool = false,
        firstOpenDate: Date? = nil,
        lastSyncDate: Date? = nil,
        cloudSyncEnabled: Bool = false
    ) {
        self.id = id
        self.disableHaptics = disableHaptics
        self.reduceMotion = reduceMotion
        self.highContrast = highContrast
        self.useDyslexiaFont = useDyslexiaFont
        self.requireAuthentication = requireAuthentication
        self.hideInAppSwitcher = hideInAppSwitcher
        self.healthKitEnabled = healthKitEnabled
        self.notificationsEnabled = notificationsEnabled
        self.defaultReminderHour = defaultReminderHour
        self.defaultReminderMinute = defaultReminderMinute
        self.preferredColorSchemeRaw = preferredColorSchemeRaw
        self.showCompletedOnDashboard = showCompletedOnDashboard
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.firstOpenDate = firstOpenDate
        self.lastSyncDate = lastSyncDate
        self.cloudSyncEnabled = cloudSyncEnabled
    }
}

// MARK: - Color Scheme Helper

extension UserPreferences {
    public enum PreferredColorScheme: String {
        case light
        case dark
        case system
    }

    public var preferredColorScheme: PreferredColorScheme {
        get {
            guard let raw = preferredColorSchemeRaw else { return .system }
            return PreferredColorScheme(rawValue: raw) ?? .system
        }
        set {
            preferredColorSchemeRaw = newValue == .system ? nil : newValue.rawValue
        }
    }
}

// MARK: - Default Reminder Time

extension UserPreferences {
    public var defaultReminderTime: DateComponents {
        var components = DateComponents()
        components.hour = defaultReminderHour
        components.minute = defaultReminderMinute
        return components
    }
}
