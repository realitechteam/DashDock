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
            .onOpenURL { url in
                handleURL(url)
            }
        } label: {
            MenuBarLabel(syncManager: syncManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(authManager: authManager, syncManager: syncManager)
                .environmentObject(updateManager)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "dashdock" else { return }
        switch url.host {
        case "activate":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let key = comps?.queryItems?.first(where: { $0.name == "key" })?.value {
                Task { await SubscriptionManager.shared.activateLicense(key) }
            }
        default:
            break
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must stay running")
    }
}
