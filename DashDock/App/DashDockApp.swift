import AppKit
import SwiftUI

@main
struct DashDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authManager = GoogleAuthManager()
    @State private var syncManager = DataSyncManager()
    @State private var appState = AppState()
    @StateObject private var updateManager = UpdateManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                authManager: authManager,
                syncManager: syncManager,
                appState: appState
            )
            .environmentObject(updateManager)
            .frame(width: 360, height: 500)
        } label: {
            MenuBarLabel(syncManager: syncManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(authManager: authManager, syncManager: syncManager)
                .environmentObject(updateManager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must stay running")
    }
}
