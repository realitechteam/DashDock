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
            Spacer()

            if !appState.subscription.isPro {
                Button {
                    // TODO: Show upgrade sheet
                } label: {
                    Text("PRO")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderless)
            }

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

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 36))
                .foregroundStyle(.blue.gradient)

            Text("Select Property")
                .font(.title3.bold())

            Text("Choose a GA4 property to monitor")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView("Loading properties...")
                    .padding()
            } else if let errorMsg {
                VStack(spacing: 8) {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") { loadProperties() }
                        .buttonStyle(.bordered)
                }
            } else if accounts.isEmpty && !showManualInput {
                VStack(spacing: 8) {
                    Text("No GA4 properties found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Enter Property ID manually") {
                        showManualInput = true
                    }
                    .buttonStyle(.bordered)
                }
            } else if showManualInput {
                manualInputView
            } else {
                propertyListView
            }

            Spacer()
        }
        .padding()
        .task { loadProperties() }
    }

    private var propertyListView: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(accounts) { account in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(account.propertySummaries ?? []) { property in
                                PropertyRow(
                                    property: property,
                                    isSelected: selectedProperty?.id == property.id
                                ) {
                                    selectedProperty = property
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                Button("Enter manually") {
                    showManualInput = true
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button("Connect") {
                    guard let prop = selectedProperty else { return }
                    saveProperty(id: prop.propertyID, name: prop.displayName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedProperty == nil)
            }
        }
    }

    private var manualInputView: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GA4 Property ID")
                    .font(.caption.bold())
                TextField("e.g. 123456789", text: $manualID)
                    .textFieldStyle(.roundedBorder)
                Text("Find it: Google Analytics → Admin → Property details")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Button("Back to list") {
                    showManualInput = false
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button("Connect") {
                    let trimmed = manualID.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    saveProperty(id: trimmed, name: "Property \(trimmed)")
                }
                .buttonStyle(.borderedProminent)
                .disabled(manualID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func loadProperties() {
        isLoading = true
        errorMsg = nil
        Task {
            let apiClient = APIClient(authManager: authManager)
            let ga4 = GA4Client(apiClient: apiClient)
            do {
                accounts = try await ga4.listAccountSummaries()
                if accounts.flatMap({ $0.propertySummaries ?? [] }).isEmpty {
                    showManualInput = true
                }
            } catch {
                errorMsg = "Failed to load properties: \(error.localizedDescription)"
            }
            isLoading = false
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
