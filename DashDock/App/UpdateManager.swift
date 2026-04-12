import Foundation
import Sparkle

/// Wrapper around Sparkle's SPUUpdater for SwiftUI integration.
/// Handles auto-update checks, manual checks, and update settings.
@MainActor
final class UpdateManager: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?

    init() {
        // Create Sparkle updater controller
        // - startingUpdater: true = start checking automatically
        // - updaterDelegate/userDriverDelegate: nil = use defaults
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Observe canCheckForUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }

    var updater: SPUUpdater {
        updaterController.updater
    }

    /// Check for updates manually (shows UI)
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Whether automatic update checks are enabled
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    /// Whether to automatically download and install updates
    var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Update check interval in seconds
    var updateCheckInterval: TimeInterval {
        get { updater.updateCheckInterval }
        set { updater.updateCheckInterval = newValue }
    }
}
