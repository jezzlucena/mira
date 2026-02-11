import LocalAuthentication
import StoreKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings screen for privacy, accessibility, and data management
struct SettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var preferences: UserPreferences?
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteConfirmation = false
    @State private var exportURL: URL?
    @State private var importResult: ImportResult?
    @State private var showImportResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var iCloudSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    @State private var showSyncRestartAlert = false
    @State private var showManageSubscriptions = false

    var body: some View {
        NavigationStack {
            Form {
                // Accessibility
                accessibilitySection

                // Privacy
                privacySection

                // HealthKit
                healthKitSection

                // Premium
                premiumSection

                // Data
                dataSection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .task {
                await loadPreferences()
            }
            #if os(iOS)
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            #else
            .onChange(of: showExportSheet) {
                if showExportSheet, let url = exportURL {
                    NSWorkspace.shared.open(url)
                    showExportSheet = false
                }
            }
            #endif
            .fileImporter(
                isPresented: $showImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Import Complete", isPresented: $showImportResult) {
                Button("OK") {}
            } message: {
                if let result = importResult {
                    Text("Imported \(result.habitsImported) habits and \(result.entriesImported) entries.")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your habits, entries, and preferences. This cannot be undone.")
            }
            .alert("Restart Required", isPresented: $showSyncRestartAlert) {
                Button("OK") {}
            } message: {
                Text("Please restart Mira for the iCloud sync change to take effect.")
            }
        }
    }

    // MARK: - Accessibility Section

    @ViewBuilder
    private var accessibilitySection: some View {
        Section {
            Toggle("Reduce Motion", isOn: binding(for: \.reduceMotion))

            Toggle("Disable Haptics", isOn: binding(for: \.disableHaptics))

            Toggle("High Contrast", isOn: binding(for: \.highContrast))

            Toggle("Dyslexia-Friendly Font", isOn: binding(for: \.useDyslexiaFont))
        } header: {
            Label("Accessibility", systemImage: "accessibility")
        } footer: {
            Text("These settings help make Mira more comfortable to use.")
        }
    }

    // MARK: - Privacy Section

    @ViewBuilder
    private var privacySection: some View {
        Section {
            Toggle("Require Face ID/Touch ID", isOn: binding(for: \.requireAuthentication))

            Toggle("Hide in App Switcher", isOn: binding(for: \.hideInAppSwitcher))
        } header: {
            Label("Privacy", systemImage: "lock.shield")
        } footer: {
            Text("Protect your data from prying eyes.")
        }
    }

    // MARK: - HealthKit Section

    @ViewBuilder
    private var healthKitSection: some View {
        Section {
            Toggle("Enable HealthKit", isOn: binding(for: \.healthKitEnabled))
                .onChange(of: preferences?.healthKitEnabled) { _, newValue in
                    if newValue == true {
                        requestHealthKitAccess()
                    }
                }
        } header: {
            Label("Health Integration", systemImage: "heart.fill")
        } footer: {
            Text("Connect to HealthKit to see correlations between your habits and health metrics like sleep and heart rate.")
        }
    }

    // MARK: - Premium Section

    @ViewBuilder
    private var premiumSection: some View {
        Section {
            // Subscription status
            HStack {
                Label("Subscription", systemImage: "crown.fill")
                Spacer()
                Text(subscriptionService.isPremium ? "Active" : "Free")
                    .foregroundStyle(subscriptionService.isPremium ? .green : .secondary)
            }

            if subscriptionService.isPremium {
                Button("Manage Subscription") {
                    showManageSubscriptions = true
                }
            } else {
                NavigationLink {
                    SubscriptionView()
                } label: {
                    Label("Upgrade to Premium", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            // iCloud Sync toggle — disabled when not premium
            Toggle(isOn: $iCloudSyncEnabled) {
                Label("Sync to iCloud", systemImage: "icloud")
            }
            .disabled(!subscriptionService.isPremium)
            .onChange(of: iCloudSyncEnabled) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnabled")
                showSyncRestartAlert = true
            }

            if subscriptionService.isPremium {
                iCloudStatusRow
            }
        } header: {
            Label("Mira Premium", systemImage: "crown")
        } footer: {
            if !subscriptionService.isPremium {
                Text("Subscribe to Mira Premium to unlock iCloud Sync and Apple Watch support.")
            } else if iCloudSyncEnabled {
                Text("Your habits and entries sync across iPhone and Apple Watch via iCloud.")
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    // MARK: - Data Section

    @ViewBuilder
    private var dataSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            Button {
                showImportSheet = true
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
            }
        } header: {
            Label("Data Management", systemImage: "externaldrive")
        } footer: {
            Text("Export as JSON for manual backup.")
        }
    }

    @ViewBuilder
    private var iCloudStatusRow: some View {
        HStack {
            Text("iCloud Status")
                .foregroundStyle(.secondary)
            Spacer()
            switch dependencies.cloudKitState {
            case .connected:
                Label("Connected", systemImage: "checkmark.icloud.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            case .unavailable:
                Label("Unavailable", systemImage: "exclamationmark.icloud.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            case .migrationRequired:
                Label("Migration Required", systemImage: "exclamationmark.icloud.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            case .subscriptionRequired:
                Label("Premium Required", systemImage: "crown.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            case .off:
                if iCloudSyncEnabled {
                    Label("Restart Required", systemImage: "arrow.clockwise.icloud.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else {
                    Label("Off", systemImage: "icloud.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .labelStyle(.titleAndIcon)
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

            Link(destination: URL(string: "https://example.com/privacy")!) {
                Label("Privacy Policy", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://example.com/support")!) {
                Label("Get Help", systemImage: "questionmark.circle")
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - Helpers

    private func loadPreferences() async {
        do {
            preferences = try dependencies.preferencesRepository.get()
        } catch {
            print("Failed to load preferences: \(error)")
        }
    }

    private func binding(for keyPath: WritableKeyPath<UserPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences?[keyPath: keyPath] ?? false },
            set: { newValue in
                preferences?[keyPath: keyPath] = newValue
                savePreferences()
            }
        )
    }

    private func savePreferences() {
        guard let preferences = preferences else { return }
        do {
            try dependencies.modelContext.save()
        } catch {
            print("Failed to save preferences: \(error)")
        }
    }

    private func requestHealthKitAccess() {
        Task {
            do {
                try await dependencies.healthKitManager.requestAuthorization()
            } catch {
                errorMessage = "Failed to request HealthKit access: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func exportData() {
        do {
            exportURL = try dependencies.exportService.exportToFile()
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
            showError = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            importResult = try dependencies.exportService.importData(from: data, mode: .merge)
            showImportResult = true
        } catch {
            errorMessage = "Failed to import data: \(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteAllData() {
        do {
            // Delete all habits (cascade deletes entries)
            let habits = try dependencies.habitRepository.fetchAllIncludingArchived()
            for habit in habits {
                try dependencies.habitRepository.delete(habit)
            }

            // Reset preferences
            try dependencies.preferencesRepository.resetToDefaults()

            // Reload
            Task { await loadPreferences() }
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Import Error

enum ImportError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the selected file"
        }
    }
}

// MARK: - Share Sheet

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview {
    SettingsView()
        .withDependencies(.shared)
}
