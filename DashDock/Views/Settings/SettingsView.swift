import SwiftUI

struct SettingsView: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager
    @EnvironmentObject var updateManager: UpdateManager

    var body: some View {
        TabView {
            AccountsSettingsView(authManager: authManager)
                .tabItem {
                    Label("Accounts", systemImage: "person.crop.circle")
                }

            PropertiesSettingsView(authManager: authManager, syncManager: syncManager)
                .tabItem {
                    Label("Properties", systemImage: "building.2")
                }

            RefreshSettingsView(syncManager: syncManager)
                .tabItem {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

            UpdateSettingsView()
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
                }

            BillingSettingsView()
                .tabItem {
                    Label("Billing", systemImage: "creditcard")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 380)
    }
}
