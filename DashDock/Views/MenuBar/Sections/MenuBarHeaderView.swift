import SwiftUI

struct MenuBarHeaderView: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager
    let appState: AppState
    let onStartSync: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if let account = authManager.currentAccount {
                    Section(account.email) {
                        if let prop = account.ga4PropertyName {
                            Label("GA4: \(prop)", systemImage: "chart.bar")
                        }
                        if let adId = account.adSenseAccountID {
                            Label("AdSense: \(adId)", systemImage: "dollarsign.circle")
                        }
                    }
                }

                Divider()

                let allAccounts = SharedDataStore.shared.loadAccounts()
                let otherAccounts = allAccounts.filter { $0.id != authManager.currentAccount?.id }
                if !otherAccounts.isEmpty {
                    Section("Switch Account") {
                        ForEach(otherAccounts) { acct in
                            Button {
                                switchToAccount(acct)
                            } label: {
                                Label(acct.email, systemImage: "person.circle")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        authManager.signIn()
                    } label: {
                        Label("Add Google Account", systemImage: "person.badge.plus")
                    }

                    Button {
                        appState.showSetup = true
                    } label: {
                        Label("Change Property", systemImage: "building.2")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    authManager.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.forward")
                }
            } label: {
                HStack(spacing: 6) {
                    if let account = authManager.currentAccount {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.ga4PropertyName ?? "DashDock")
                                .font(.headline)
                                .lineLimit(1)
                            Text(account.email)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button {
                Task { await syncManager.refreshAll() }
            } label: {
                Image(systemName: syncManager.isRefreshing ? "arrow.clockwise.circle" : "arrow.clockwise")
                    .rotationEffect(.degrees(syncManager.isRefreshing ? 360 : 0))
                    .animation(syncManager.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncManager.isRefreshing)
            }
            .buttonStyle(.borderless)

            Menu {
                SettingsLink { Text("Settings") }
                    .keyboardShortcut(",", modifiers: .command)

                Button("Hide DashDock") {
                    NSApplication.shared.hide(nil)
                }
                .keyboardShortcut("h", modifiers: .command)

                Divider()

                Button("Exit DashDock", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "gear")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func switchToAccount(_ account: GoogleAccount) {
        SharedDataStore.shared.saveCurrentAccount(account)
        authManager.currentAccount = account

        if account.ga4PropertyID == nil {
            appState.showSetup = true
        } else {
            appState.showSetup = false
            onStartSync()
        }
    }
}
