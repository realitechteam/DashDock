import SwiftUI

struct MenuBarPopover: View {
    let authManager: GoogleAuthManager
    let syncManager: DataSyncManager
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !authManager.isAuthenticated {
                signInContent
            } else if needsSetup {
                setupContent
            } else {
                authenticatedContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: needsSetup)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .background(.regularMaterial)
        .task {
            // Auto-start sync on launch if already authenticated
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

    // MARK: - Setup Flow

    private var setupContent: some View {
        PropertyPickerView(authManager: authManager, appState: appState) {
            startSync()
        }
    }

    // MARK: - Authenticated Content

    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                dashboardContent
                    .padding()
            }
            footerView
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            // Account menu — click to switch accounts or edit properties
            Menu {
                // Current account info
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

                // Other accounts
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

                // Actions
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

            SettingsLink {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func switchToAccount(_ account: GoogleAccount) {
        SharedDataStore.shared.saveCurrentAccount(account)
        authManager.currentAccount = account

        // Check if this account has a property configured
        if account.ga4PropertyID == nil {
            appState.showSetup = true
        } else {
            appState.showSetup = false
            startSync()
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        // Realtime active users — hero card
        if let realtime = syncManager.ga4Realtime {
            RealtimeHeroCard(data: realtime)
        } else {
            LoadingCard(title: "Loading realtime data...")
        }

        // Summary metrics with trends
        if let summary = syncManager.ga4Summary {
            SummaryCardsView(data: summary)

            // Daily charts
            DailyBarChart(
                title: "Pageviews (7 days)",
                data: summary.dailyPageviews,
                color: .purple
            )

            DailyBarChart(
                title: "Sessions (7 days)",
                data: summary.dailySessions,
                color: .green
            )
        }

        // AdSense Revenue
        if let adsense = syncManager.adSenseRevenue {
            AdSenseCard(data: adsense)
        }

        // Top pages (realtime)
        if let realtime = syncManager.ga4Realtime, !realtime.topPages.isEmpty {
            TopPagesCard(pages: realtime.topPages)
        }
    }

    @ViewBuilder
    private var footerView: some View {
        HStack {
            if let error = syncManager.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption2)
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let ts = syncManager.ga4Realtime?.timestamp {
                Text("Updated \(ts.timeAgoDisplay())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Sign In

    private var signInContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text("DashDock")
                .font(.title2.bold())

            Text("Monitor Google Analytics, AdSense & Search Console right from your Desktop.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                authManager.signIn()
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(authManager.isLoading)

            if authManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

// MARK: - Property Picker View

struct PropertyPickerView: View {
    let authManager: GoogleAuthManager
    let appState: AppState
    let onComplete: () -> Void

    @State private var accounts: [GA4AccountSummary] = []
    @State private var selectedProperty: GA4PropertySummary?
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var manualID = ""
    @State private var showManualInput = false
    @State private var needsAdminAPI = false  // true when 403 = Admin API not enabled

    @State private var isConnecting = false

    /// Other accounts that already have a property configured (can switch back)
    private var configuredAccounts: [GoogleAccount] {
        SharedDataStore.shared.loadAccounts().filter {
            $0.id != authManager.currentAccount?.id && $0.ga4PropertyID != nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top bar with escape options
            HStack {
                if !configuredAccounts.isEmpty {
                    Menu {
                        ForEach(configuredAccounts) { acct in
                            Button {
                                switchToAccount(acct)
                            } label: {
                                Label(acct.email, systemImage: "person.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Switch Account")
                        }
                        .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Spacer()

                Button(role: .destructive) {
                    authManager.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundStyle(.blue.gradient)

            Text("Connect GA4 Property")
                .font(.title3.bold())

            if let email = authManager.currentAccount?.email {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Content area
            if isLoading {
                ProgressView("Loading properties...")
                    .padding()
            } else if needsAdminAPI {
                enableAdminAPIView
            } else if !accounts.isEmpty && !showManualInput {
                propertyListView
            } else {
                manualInputView
            }

            Spacer()
        }
        .padding(.bottom)
        .task { loadProperties() }
    }

    /// Shown when Analytics Admin API is not enabled — guide user to enable it
    private var enableAdminAPIView: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("One more step")
                    .font(.callout.bold())

                Text("DashDock needs the **Analytics Admin API** to list your properties. Enable it in Google Cloud Console (takes 30 seconds).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Step-by-step
            VStack(alignment: .leading, spacing: 8) {
                StepRow(number: 1, text: "Click the button below to open Cloud Console")
                StepRow(number: 2, text: "Click **\"Enable\"** on the API page")
                StepRow(number: 3, text: "Come back here and tap **\"Done, load properties\"**")
            }
            .padding(.horizontal, 24)

            Button {
                let url = URL(string: "https://console.cloud.google.com/apis/library/analyticsadmin.googleapis.com")!
                NSWorkspace.shared.open(url)
            } label: {
                HStack {
                    Image(systemName: "safari")
                    Text("Open Google Cloud Console")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Button {
                needsAdminAPI = false
                errorMsg = nil
                loadProperties()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Done, load properties")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)

            Button("Skip — enter Property ID manually") {
                needsAdminAPI = false
                showManualInput = true
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    /// Simple manual input (no error context needed when user chose this path)
    private var manualInputView: some View {
        VStack(spacing: 12) {
            if let errorMsg, !needsAdminAPI {
                Text(friendlyError(errorMsg))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("GA4 Property ID")
                    .font(.caption.bold())

                TextField("e.g. 123456789", text: $manualID)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { connectManualID() }

                Text("Find in: **analytics.google.com** → Admin → Property details → Property ID")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)

            Button {
                connectManualID()
            } label: {
                Text("Connect")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(manualID.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 24)

            if !accounts.isEmpty {
                Button("Back to property list") {
                    showManualInput = false
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
    }

    private var propertyListView: some View {
        VStack(spacing: 12) {
            if isConnecting {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                Text("Tap a property to connect")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(accounts) { account in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.displayName)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                ForEach(account.propertySummaries ?? []) { property in
                                    Button {
                                        connectProperty(property)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(property.displayName)
                                                    .font(.callout)
                                                Text("ID: \(property.propertyID)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.right.circle")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)

                Button("Enter manually instead") {
                    showManualInput = true
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
    }

    private func loadProperties() {
        isLoading = true
        errorMsg = nil
        needsAdminAPI = false
        Task {
            let apiClient = APIClient(authManager: authManager)
            let ga4 = GA4Client(apiClient: apiClient)
            do {
                accounts = try await ga4.listAccountSummaries()
                if accounts.flatMap({ $0.propertySummaries ?? [] }).isEmpty {
                    showManualInput = true
                }
            } catch {
                let msg = error.localizedDescription
                errorMsg = msg
                // Detect Admin API not enabled
                if msg.contains("Admin API") || msg.contains("not been used") ||
                   msg.contains("not been enabled") || msg.contains("not enabled") ||
                   msg.contains("403") || msg.contains("Access denied") {
                    needsAdminAPI = true
                } else {
                    showManualInput = true
                }
            }
            isLoading = false
        }
    }

    private func connectProperty(_ property: GA4PropertySummary) {
        isConnecting = true
        // Brief delay for visual feedback, then save + transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                saveProperty(id: property.propertyID, name: property.displayName)
            }
        }
    }

    private func connectManualID() {
        let trimmed = manualID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isConnecting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                saveProperty(id: trimmed, name: "Property \(trimmed)")
            }
        }
    }

    private func saveProperty(id: String, name: String) {
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

        appState.showSetup = false
        onComplete()
    }

    private func switchToAccount(_ account: GoogleAccount) {
        SharedDataStore.shared.saveCurrentAccount(account)
        authManager.currentAccount = account
        appState.showSetup = false
        onComplete()
    }

    /// Shorten Google's verbose error messages
    private func friendlyError(_ msg: String) -> String {
        if msg.contains("Admin API has not been used") || msg.contains("not been enabled") {
            return "Google Analytics Admin API not enabled. Enter Property ID manually below."
        }
        if msg.contains("403") || msg.contains("Access denied") {
            return "No permission to list properties. Enter Property ID manually below."
        }
        if msg.contains("401") || msg.contains("unauthorized") {
            return "Session expired. Try signing out and back in."
        }
        return msg
    }
}

private struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption2.bold())
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PropertyRow: View {
    let property: GA4PropertySummary
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(property.displayName)
                        .font(.callout)
                    Text("ID: \(property.propertyID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard Cards

struct RealtimeHeroCard: View {
    let data: CachedGA4Realtime

    var body: some View {
        VStack(spacing: 4) {
            Text("\(data.activeUsers)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.blue.gradient)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: data.activeUsers)
            Text("Active Users Right Now")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SummaryCardsView: View {
    let data: CachedGA4Summary

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
            MetricCard(
                title: "Pageviews",
                value: data.pageviews.formattedCompact(),
                icon: "eye.fill",
                color: .purple,
                change: data.pageviewsChange,
                sparklineData: data.dailyPageviews.map(\.value)
            )
            MetricCard(
                title: "Sessions",
                value: data.sessions.formattedCompact(),
                icon: "person.2.fill",
                color: .green,
                change: data.sessionsChange,
                sparklineData: data.dailySessions.map(\.value)
            )
            MetricCard(
                title: "New Users",
                value: data.newUsers.formattedCompact(),
                icon: "person.badge.plus",
                color: .orange,
                change: data.newUsersChange,
                sparklineData: data.dailyNewUsers.map(\.value)
            )
        }
        .padding(.top, 4)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var change: Double? = nil
    var sparklineData: [Int] = []

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .contentTransition(.numericText())

            if change != nil || !sparklineData.isEmpty {
                HStack(spacing: 4) {
                    TrendBadge(change: change)

                    if !sparklineData.isEmpty {
                        SparklineChart(data: sparklineData, color: color)
                            .frame(width: 36)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TopPagesCard: View {
    let pages: [CachedGA4Realtime.PageView]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Pages")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(pages.prefix(5).enumerated()), id: \.offset) { _, page in
                HStack {
                    Text(page.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("\(page.activeUsers)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
    }
}

struct LoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Helpers

extension Date {
    func timeAgoDisplay() -> String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
