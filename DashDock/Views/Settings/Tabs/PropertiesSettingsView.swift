import SwiftUI

struct PropertiesSettingsView: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager

    @State private var accounts: [GA4AccountSummary] = []
    @State private var fetchedAt: Date?
    @State private var isLoading = false
    @State private var manualID = ""
    @State private var showManual = false
    @State private var errorMsg: String?
    @State private var didInitialLoad = false

    private let cache = SettingsCacheStore.shared

    var body: some View {
        Form {
            Section("Google Analytics 4") {
                if let fetchedAt {
                    Text("Updated \(fetchedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if isLoading {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading properties...").font(.caption)
                    }
                } else if let errorMsg {
                    errorView(errorMsg)
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
        .task { await loadIfNeeded() }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Failed to load properties").font(.callout.bold())
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if message.contains("not been used") || message.contains("not been enabled") || message.contains("not enabled") {
                Text("Enable the **Google Analytics Admin API** in Google Cloud Console, then retry.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Retry") {
                    errorMsg = nil
                    Task { await load(force: true) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Enter ID manually") {
                    errorMsg = nil
                    showManual = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
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
                            Text(property.displayName).font(.callout)
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

            Button("Enter ID manually") { showManual = true }
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

    private func loadIfNeeded() async {
        guard authManager.isAuthenticated else { return }
        let accountID = authManager.currentAccount?.id

        if didInitialLoad, accountID == cache.ga4AccountID { return }

        if let cached = cache.ga4Cache(for: accountID) {
            accounts = cached.accounts
            fetchedAt = cached.fetchedAt
            showManual = accounts.flatMap({ $0.propertySummaries ?? [] }).isEmpty
            didInitialLoad = true
            return
        }

        await load(force: false)
    }

    private func load(force: Bool) async {
        guard authManager.isAuthenticated else { return }
        let accountID = authManager.currentAccount?.id

        if !force, didInitialLoad, accountID == cache.ga4AccountID, !accounts.isEmpty { return }

        isLoading = true
        errorMsg = nil
        let apiClient = APIClient(authManager: authManager)
        let ga4 = GA4Client(apiClient: apiClient)

        do {
            let fetched = try await ga4.listAccountSummaries()
            accounts = fetched
            cache.setGA4(accounts: fetched, for: accountID)
            fetchedAt = cache.ga4FetchedAt
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

        let apiClient = APIClient(authManager: authManager)
        syncManager.configure(apiClient: apiClient)
        syncManager.startPolling()
    }
}

struct AdSenseAccountSection: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager

    @State private var accounts: [AdSenseAccount] = []
    @State private var fetchedAt: Date?
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var didInitialLoad = false

    private let cache = SettingsCacheStore.shared

    var body: some View {
        Group {
            if let fetchedAt, authManager.currentAccount?.id == cache.adSenseAccountID {
                Text("Updated \(fetchedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading AdSense accounts...").font(.caption)
                }
            } else if let errorMsg {
                errorView(errorMsg)
            } else if accounts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No AdSense accounts found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reload") { Task { await load(force: true) } }
                        .font(.caption)
                }
            } else {
                accountList
            }
        }
        .task { await loadIfNeeded() }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("Failed to load AdSense").font(.caption.bold())
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if message.contains("not been used") || message.contains("not been enabled") || message.contains("not enabled") {
                Text("Enable the **AdSense Management API** in Google Cloud Console, then retry.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if message.contains("Access denied") || message.contains("403") {
                Text("Make sure this Google account has an active AdSense account, and the AdSense Management API is enabled.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Retry") { Task { await load(force: true) } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(accounts) { account in
                HStack {
                    VStack(alignment: .leading) {
                        Text(account.displayName).font(.callout)
                        Text(account.accountID)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if authManager.currentAccount?.adSenseAccountName == account.name {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Connect") { selectAdSense(account) }
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

    private func loadIfNeeded() async {
        guard authManager.isAuthenticated else { return }
        let accountID = authManager.currentAccount?.id

        if didInitialLoad, accountID == cache.adSenseAccountID { return }

        if let cached = cache.adSenseCache(for: accountID) {
            accounts = cached.accounts
            fetchedAt = cached.fetchedAt
            didInitialLoad = true
            return
        }

        await load(force: false)
    }

    private func load(force: Bool) async {
        guard authManager.isAuthenticated else { return }
        let accountID = authManager.currentAccount?.id

        if !force, didInitialLoad, accountID == cache.adSenseAccountID, !accounts.isEmpty { return }

        isLoading = true
        errorMsg = nil
        let apiClient = APIClient(authManager: authManager)
        let client = AdSenseClient(apiClient: apiClient)
        do {
            let fetched = try await client.listAccounts()
            accounts = fetched
            cache.setAdSense(accounts: fetched, for: accountID)
            fetchedAt = cache.adSenseFetchedAt
            didInitialLoad = true
        } catch {
            errorMsg = "Failed to load: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func selectAdSense(_ adAccount: AdSenseAccount) {
        guard var account = authManager.currentAccount else { return }
        account.adSenseAccountID = adAccount.accountID
        account.adSenseAccountName = adAccount.name
        save(account)
    }

    private func disconnectAdSense() {
        guard var account = authManager.currentAccount else { return }
        account.adSenseAccountID = nil
        account.adSenseAccountName = nil
        save(account)
    }

    private func save(_ account: GoogleAccount) {
        SharedDataStore.shared.saveCurrentAccount(account)
        authManager.currentAccount = account

        var all = SharedDataStore.shared.loadAccounts()
        if let idx = all.firstIndex(where: { $0.id == account.id }) {
            all[idx] = account
            SharedDataStore.shared.saveAccounts(all)
        }

        let apiClient = APIClient(authManager: authManager)
        syncManager.configure(apiClient: apiClient)
        syncManager.startPolling()
    }
}
