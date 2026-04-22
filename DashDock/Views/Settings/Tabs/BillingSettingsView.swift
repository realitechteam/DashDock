import SwiftUI

struct BillingSettingsView: View {
    @State private var subscription = SubscriptionManager.shared
    @State private var licenseInput = ""
    @State private var selectedCurrency = AppCurrency.fromStoredCode(SharedDataStore.shared.loadPreferredCurrency())

    var body: some View {
        Form {
            planSection
            activateSection
            currencySection
            proFeaturesSection

            Section {
                Text("Checkout opens in browser via Polar. After purchase, your license key is auto-applied if you click the success link, or copy it here manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var planSection: some View {
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
                    Button("Upgrade") { subscription.openCheckout() }
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
    }

    private var activateSection: some View {
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
    }

    private var currencySection: some View {
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
    }

    private var proFeaturesSection: some View {
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
    }
}
