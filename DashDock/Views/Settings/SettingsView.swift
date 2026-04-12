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

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 380)
    }
}

// MARK: - Accounts

struct AccountsSettingsView: View {
    let authManager: GoogleAuthManager

    var body: some View {
        Form {
            if let account = authManager.currentAccount {
                Section("Connected Account") {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(.headline)
                            Text(account.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let prop = account.ga4PropertyName {
                                Text("Property: \(prop)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    }
                }
            } else {
                Section {
                    VStack(spacing: 12) {
                        Text("No account connected")
                            .foregroundStyle(.secondary)
                        Button("Sign in with Google") {
                            authManager.signIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Properties

struct PropertiesSettingsView: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager

    @State private var accounts: [GA4AccountSummary] = []
    @State private var selectedPropertyID: String = ""
    @State private var isLoading = false
    @State private var manualID = ""
    @State private var showManual = false

    var body: some View {
        Form {
            Section("Google Analytics 4") {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading properties...")
                            .font(.caption)
                    }
                } else if showManual {
                    manualSection
                } else if !accounts.isEmpty {
                    propertyPickerSection
                } else {
                    manualSection
                }
            }

            Section("AdSense") {
                Text("Coming in Phase 2")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Search Console") {
                Text("Coming in Phase 3")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await loadProperties() }
    }

    private var propertyPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(accounts) { account in
                Text(account.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(account.propertySummaries ?? []) { property in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(property.displayName)
                                .font(.callout)
                            Text("ID: \(property.propertyID)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if authManager.currentAccount?.ga4PropertyID == property.propertyID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Select") {
                                selectProperty(id: property.propertyID, name: property.displayName)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button("Enter ID manually") {
                showManual = true
            }
            .font(.caption)
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("GA4 Property ID (e.g., 123456789)", text: $manualID)
                .onAppear {
                    manualID = authManager.currentAccount?.ga4PropertyID ?? ""
                }
            HStack {
                if !accounts.isEmpty {
                    Button("Back to list") { showManual = false }
                        .font(.caption)
                }
                Spacer()
                Button("Save") {
                    selectProperty(id: manualID.trimmingCharacters(in: .whitespaces), name: "Property \(manualID)")
                }
                .disabled(manualID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func loadProperties() async {
        guard authManager.isAuthenticated else { return }
        isLoading = true
        let apiClient = APIClient(authManager: authManager)
        let ga4 = GA4Client(apiClient: apiClient)
        do {
            accounts = try await ga4.listAccountSummaries()
        } catch {
            showManual = true
        }
        isLoading = false
    }

    private func selectProperty(id: String, name: String) {
        guard var account = authManager.currentAccount else { return }
        account.ga4PropertyID = id
        account.ga4PropertyName = name
        SharedDataStore.shared.saveCurrentAccount(account)
        authManager.currentAccount = account

        var all = SharedDataStore.shared.loadAccounts()
        if let idx = all.firstIndex(where: { $0.id == account.id }) {
            all[idx] = account
            SharedDataStore.shared.saveAccounts(all)
        }

        // Restart sync with new property
        let apiClient = APIClient(authManager: authManager)
        syncManager.configure(apiClient: apiClient)
        syncManager.startPolling()
    }
}

// MARK: - Refresh

struct RefreshSettingsView: View {
    let syncManager: DataSyncManager
    @State private var realtimeSeconds: Double = 30
    @State private var reportMinutes: Double = 5

    var body: some View {
        Form {
            Section("Realtime Data") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fetch active users every \(Int(realtimeSeconds)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $realtimeSeconds, in: 15...120, step: 15)
                        Text("\(Int(realtimeSeconds))s")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section("Reports") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fetch pageviews/sessions every \(Int(reportMinutes)) minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $reportMinutes, in: 1...30, step: 1)
                        Text("\(Int(reportMinutes))m")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section {
                Button("Apply & Restart") {
                    syncManager.realtimeInterval = realtimeSeconds
                    syncManager.reportInterval = reportMinutes * 60
                    syncManager.startPolling()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            realtimeSeconds = syncManager.realtimeInterval
            reportMinutes = syncManager.reportInterval / 60
        }
    }
}

// MARK: - Updates

struct UpdateSettingsView: View {
    @EnvironmentObject var updateManager: UpdateManager

    @State private var autoCheck = true
    @State private var autoInstall = true

    var body: some View {
        Form {
            Section("Auto-Update") {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { _, newValue in
                        updateManager.automaticallyChecksForUpdates = newValue
                    }

                Toggle("Automatically download and install updates", isOn: $autoInstall)
                    .onChange(of: autoInstall) { _, newValue in
                        updateManager.automaticallyDownloadsUpdates = newValue
                    }
            }

            Section("Manual") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current version: \(appVersion)")
                            .font(.callout)
                        if let lastCheck = updateManager.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Check for Updates") {
                        updateManager.checkForUpdates()
                    }
                    .disabled(!updateManager.canCheckForUpdates)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How it works")
                        .font(.caption.bold())
                    Text("DashDock uses Sparkle to check for updates from realitech.dev. When a new version is available, it will be downloaded and installed automatically (or you can check manually).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            autoCheck = updateManager.automaticallyChecksForUpdates
            autoInstall = updateManager.automaticallyDownloadsUpdates
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}

// MARK: - About

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text("DashDock")
                .font(.title.bold())

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Real-time Google Analytics, AdSense & Search Console monitoring for your Mac Desktop.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 60)

            VStack(spacing: 8) {
                Text("Realitech Team")
                    .font(.headline)

                Link(destination: URL(string: "https://realitech.dev")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("realitech.dev")
                    }
                    .font(.callout)
                }

                Link(destination: URL(string: "mailto:partner@realitech.dev")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                        Text("partner@realitech.dev")
                    }
                    .font(.callout)
                }

                HStack(spacing: 4) {
                    Image(systemName: "phone")
                    Text("+84 345 678 462")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Made with ♥ in Vietnam")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }
}
