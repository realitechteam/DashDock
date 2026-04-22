import SwiftUI

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
    @State private var needsAdminAPI = false

    @State private var isConnecting = false

    private var configuredAccounts: [GoogleAccount] {
        SharedDataStore.shared.loadAccounts().filter {
            $0.id != authManager.currentAccount?.id && $0.ga4PropertyID != nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
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

            if isLoading {
                ProgressView("Loading properties...")
                    .padding()
            } else if needsAdminAPI {
                EnableAdminAPIView(onRetry: {
                    needsAdminAPI = false
                    errorMsg = nil
                    loadProperties()
                }, onSkip: {
                    needsAdminAPI = false
                    showManualInput = true
                })
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
