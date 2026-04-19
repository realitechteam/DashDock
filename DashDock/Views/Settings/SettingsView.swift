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
    @State private var errorMsg: String?
    @State private var didInitialLoad = false

    private static var cachedAccountID: String?
    private static var cachedAccounts: [GA4AccountSummary] = []
    private static var cachedAt: Date?

    var body: some View {
        Form {
            Section("Google Analytics 4") {
                if let cachedAt = Self.cachedAt {
                    Text("Updated \(cachedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading properties...")
                            .font(.caption)
                    }
                } else if let errorMsg {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Failed to load properties")
                                .font(.callout.bold())
                        }

                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        if errorMsg.contains("not been used") || errorMsg.contains("not been enabled") || errorMsg.contains("not enabled") {
                            Text("Enable the **Google Analytics Admin API** in Google Cloud Console, then retry.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        HStack {
                            Button("Retry") {
                                self.errorMsg = nil
                                Task { await loadProperties(force: true) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Enter ID manually") {
                                self.errorMsg = nil
                                showManual = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
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
                AdSenseAccountSection(authManager: authManager, syncManager: syncManager)
            }

            Section("Search Console") {
                Text("Coming in Phase 3")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await loadPropertiesIfNeeded() }
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

    private func loadPropertiesIfNeeded() async {
        guard authManager.isAuthenticated else { return }

        let accountID = authManager.currentAccount?.id
        if didInitialLoad, accountID == Self.cachedAccountID {
            return
        }

        if accountID == Self.cachedAccountID, !Self.cachedAccounts.isEmpty {
            accounts = Self.cachedAccounts
            showManual = accounts.flatMap({ $0.propertySummaries ?? [] }).isEmpty
            didInitialLoad = true
            return
        }

        await loadProperties(force: false)
    }

    private func loadProperties(force: Bool) async {
        guard authManager.isAuthenticated else { return }

        let accountID = authManager.currentAccount?.id
        if !force,
           didInitialLoad,
           accountID == Self.cachedAccountID,
           !accounts.isEmpty {
            return
        }

        isLoading = true
        errorMsg = nil
        let apiClient = APIClient(authManager: authManager)
        let ga4 = GA4Client(apiClient: apiClient)

        do {
            let fetched = try await ga4.listAccountSummaries()
            accounts = fetched
            Self.cachedAccounts = fetched
            Self.cachedAccountID = accountID
            Self.cachedAt = Date()
            showManual = fetched.isEmpty || fetched.flatMap({ $0.propertySummaries ?? [] }).isEmpty
            didInitialLoad = true
        } catch {
            errorMsg = error.localizedDescription
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

// MARK: - AdSense Account Picker

struct AdSenseAccountSection: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager

    @State private var adSenseAccounts: [AdSenseAccount] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var didInitialLoad = false

    private static var cachedAccountID: String?
    private static var cachedAdSenseAccounts: [AdSenseAccount] = []
    private static var cachedAt: Date?

    var body: some View {
        Group {
            if let cachedAt = Self.cachedAt,
               authManager.currentAccount?.id == Self.cachedAccountID {
                Text("Updated \(cachedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading AdSense accounts...")
                        .font(.caption)
                }
            } else if let errorMsg {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Failed to load AdSense")
                            .font(.caption.bold())
                    }

                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if errorMsg.contains("not been used") || errorMsg.contains("not been enabled") || errorMsg.contains("not enabled") {
                        Text("Enable the **AdSense Management API** in Google Cloud Console, then retry.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if errorMsg.contains("Access denied") || errorMsg.contains("403") {
                        Text("Make sure this Google account has an active AdSense account, and the AdSense Management API is enabled.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Button("Retry") { loadAccounts(force: true) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else if adSenseAccounts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No AdSense accounts found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reload") { loadAccounts(force: true) }
                        .font(.caption)
                }
            } else {
                ForEach(adSenseAccounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.displayName)
                                .font(.callout)
                            Text(account.accountID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if authManager.currentAccount?.adSenseAccountName == account.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Connect") {
                                selectAdSense(account)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                if authManager.currentAccount?.adSenseAccountName != nil {
                    Button("Disconnect AdSense", role: .destructive) {
                        disconnectAdSense()
                    }
                    .font(.caption)
                }
            }
        }
        .task { loadAccountsIfNeeded() }
    }

    private func loadAccountsIfNeeded() {
        guard authManager.isAuthenticated else { return }

        let accountID = authManager.currentAccount?.id
        if didInitialLoad, accountID == Self.cachedAccountID {
            return
        }

        if accountID == Self.cachedAccountID, !Self.cachedAdSenseAccounts.isEmpty {
            adSenseAccounts = Self.cachedAdSenseAccounts
            didInitialLoad = true
            return
        }

        loadAccounts(force: false)
    }

    private func loadAccounts(force: Bool) {
        guard authManager.isAuthenticated else { return }

        let accountID = authManager.currentAccount?.id
        if !force,
           didInitialLoad,
           accountID == Self.cachedAccountID,
           !adSenseAccounts.isEmpty {
            return
        }

        isLoading = true
        errorMsg = nil
        Task {
            let apiClient = APIClient(authManager: authManager)
            let client = AdSenseClient(apiClient: apiClient)
            do {
                let fetched = try await client.listAccounts()
                adSenseAccounts = fetched
                Self.cachedAdSenseAccounts = fetched
                Self.cachedAccountID = accountID
                Self.cachedAt = Date()
                didInitialLoad = true
            } catch {
                errorMsg = "Failed to load: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func selectAdSense(_ adAccount: AdSenseAccount) {
        guard var account = authManager.currentAccount else { return }
        account.adSenseAccountID = adAccount.accountID
        account.adSenseAccountName = adAccount.name
        saveAccount(account)
    }

    private func disconnectAdSense() {
        guard var account = authManager.currentAccount else { return }
        account.adSenseAccountID = nil
        account.adSenseAccountName = nil
        saveAccount(account)
    }

    private func saveAccount(_ account: GoogleAccount) {
        SharedDataStore.shared.saveCurrentAccount(account)
        authManager.currentAccount = account

        var all = SharedDataStore.shared.loadAccounts()
        if let idx = all.firstIndex(where: { $0.id == account.id }) {
            all[idx] = account
            SharedDataStore.shared.saveAccounts(all)
        }

        // Restart sync
        let apiClient = APIClient(authManager: authManager)
        syncManager.configure(apiClient: apiClient)
        syncManager.startPolling()
    }
}

// MARK: - Billing

struct BillingSettingsView: View {
    @State private var subscription = SubscriptionManager.shared
    @State private var licenseInput = ""
    @State private var selectedCurrency = AppCurrency.fromStoredCode(SharedDataStore.shared.loadPreferredCurrency())

    var body: some View {
        Form {
            Section("Plan") {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.isPro ? "DashDock Pro" : "DashDock Free")
                            .font(.headline)
                        if let displayKey = subscription.licenseDisplayKey {
                            Text("License: \(displayKey)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let expires = subscription.licenseExpiresAt {
                            Text("Expires: \(expires.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let validated = subscription.lastValidatedAt {
                            Text("Last validated: \(validated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    if !subscription.isPro {
                        Button("Upgrade") {
                            subscription.openCheckout()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Monthly — $0.99 / month", systemImage: "calendar")
                    Label("Annual — $9.99 / year", systemImage: "calendar.badge.clock")
                    Label("3-day free trial on Annual", systemImage: "sparkles")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Activate License") {
                TextField("Enter Polar license key", text: $licenseInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Activate") {
                        Task { await subscription.activateLicense(licenseInput) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || subscription.isWorking)

                    Button("Validate") {
                        Task { await subscription.validateCurrentLicense() }
                    }
                    .disabled(subscription.isWorking)

                    Spacer()

                    if subscription.hasStoredLicense {
                        Button("Clear License", role: .destructive) {
                            subscription.clearLicense()
                            licenseInput = ""
                        }
                    }
                }

                if subscription.isWorking {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Checking Polar license...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = subscription.billingError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Currency") {
                Picker("Preferred Currency", selection: $selectedCurrency) {
                    ForEach(AppCurrency.allCases, id: \.self) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedCurrency) { _, newValue in
                    SharedDataStore.shared.savePreferredCurrency(newValue.code)
                }

                Text("You can also say: \"Hey Siri, change DashDock currency to USD\".")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Pro Features") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Widgets on Home Screen and Lock Screen", systemImage: "rectangle.3.group")
                    Label("Apple Watch companion app", systemImage: "applewatch")
                    Label("\"Hey Siri\" currency switching", systemImage: "mic")
                    Label("Change currency", systemImage: "coloncurrencysign.circle")
                    Label("Remove ads", systemImage: "nosign")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Text("Checkout opens in browser via Polar. After purchase, copy your license key here to activate Pro on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
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
