import SwiftUI

struct MenuBarPopover: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !authManager.isAuthenticated {
                SignInView(authManager: authManager)
            } else if needsSetup {
                PropertyPickerView(authManager: authManager, appState: appState) {
                    startSync()
                }
            } else {
                authenticatedContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: needsSetup)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .background(.regularMaterial)
        .task {
            if authManager.isAuthenticated, authManager.currentAccount?.ga4PropertyID != nil {
                startSync()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth {
                if authManager.currentAccount?.ga4PropertyID == nil {
                    appState.showSetup = true
                } else {
                    startSync()
                }
            } else {
                syncManager.stopPolling()
            }
        }
    }

    private var needsSetup: Bool {
        appState.showSetup || authManager.currentAccount?.ga4PropertyID == nil
    }

    private func startSync() {
        let apiClient = APIClient(authManager: authManager)
        syncManager.configure(apiClient: apiClient)
        syncManager.startPolling()
    }

    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            MenuBarHeaderView(authManager: authManager, syncManager: syncManager, appState: appState, onStartSync: startSync)
            Divider()
            ScrollView {
                DashboardContentView(syncManager: syncManager)
                    .padding()
            }
            MenuBarFooterView(syncManager: syncManager)
        }
    }
}
