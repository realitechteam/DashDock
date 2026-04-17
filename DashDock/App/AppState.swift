import AppKit
import Security
import SwiftUI

@Observable
@MainActor
final class AppState {
    var selectedTab: Tab = .analytics
    var showSetup = false
    var subscription = SubscriptionManager.shared

    enum Tab: String, CaseIterable {
        case analytics = "Analytics"
        case adsense = "AdSense"
        case searchConsole = "Search Console"
    }
}

enum AppTier: String, Codable {
    case free
    case pro
}

@Observable
@MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    var currentTier: AppTier = .free
    var licenseDisplayKey: String?
    var licenseExpiresAt: Date?
    var lastValidatedAt: Date?
    var billingError: String?
    var isWorking = false
    var hasStoredLicense = false

    let freeMaxProperties = 1
    let freeRefreshInterval: TimeInterval = 120
    let freeWidgetFamilies: Set<String> = ["systemSmall"]

    let proMaxProperties = 10
    let proRefreshInterval: TimeInterval = 30
    let proWidgetFamilies: Set<String> = ["systemSmall", "systemMedium", "systemLarge"]

    var isPro: Bool { currentTier == .pro }

    var maxProperties: Int {
        isPro ? proMaxProperties : freeMaxProperties
    }

    var minRefreshInterval: TimeInterval {
        isPro ? proRefreshInterval : freeRefreshInterval
    }

    private let defaults = UserDefaults.standard
    private let tierKey = "app_tier"
    private let displayKeyKey = "polar_license_display_key"
    private let expiresAtKey = "polar_license_expires_at"
    private let lastValidatedKey = "polar_license_last_validated"

    private let licenseService = "com.bami.dashdock.polar"
    private let licenseKeyAccount = "license_key"
    private let activationIDAccount = "license_activation_id"

    init() {
        loadTier()
        loadLicenseMetadata()
        Task { await restore() }
    }

    func upgrade() {
        openCheckout()
    }

    func restore() async {
        guard let key = loadKeychainString(account: licenseKeyAccount) else {
            currentTier = .free
            saveTier()
            hasStoredLicense = false
            return
        }

        hasStoredLicense = true
        await validateLicenseKey(key)
    }

    func openCheckout() {
        billingError = nil
        guard let checkoutURL else {
            billingError = "Missing POLAR_CHECKOUT_URL in Config.xcconfig."
            return
        }
        NSWorkspace.shared.open(checkoutURL)
    }

    func activateLicense(_ rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            billingError = "Please enter a license key."
            return
        }

        hasStoredLicense = true
        saveKeychainString(key, account: licenseKeyAccount)
        await validateLicenseKey(key)
    }

    func validateCurrentLicense() async {
        guard let key = loadKeychainString(account: licenseKeyAccount) else {
            billingError = "No stored license key found."
            hasStoredLicense = false
            return
        }

        hasStoredLicense = true
        await validateLicenseKey(key)
    }

    func clearLicense() {
        deleteKeychain(service: licenseService, account: licenseKeyAccount)
        deleteKeychain(service: licenseService, account: activationIDAccount)
        defaults.removeObject(forKey: displayKeyKey)
        defaults.removeObject(forKey: expiresAtKey)
        defaults.removeObject(forKey: lastValidatedKey)

        hasStoredLicense = false
        licenseDisplayKey = nil
        licenseExpiresAt = nil
        lastValidatedAt = nil
        currentTier = .free
        saveTier()
        billingError = nil
    }

    private func validateLicenseKey(_ key: String) async {
        guard let organizationID else {
            billingError = "Missing POLAR_ORGANIZATION_ID in Config.xcconfig."
            currentTier = .free
            saveTier()
            return
        }

        isWorking = true
        billingError = nil
        defer { isWorking = false }

        do {
            let activationID = await registerActivationIfPossible(key: key, organizationID: organizationID)
            let response = try await validate(key: key, organizationID: organizationID, activationID: activationID)

            guard response.status == "granted" else {
                throw PolarLicenseError.invalidStatus(response.status)
            }

            if let expectedBenefitID, response.benefitID != expectedBenefitID {
                throw PolarLicenseError.wrongBenefit
            }

            currentTier = .pro
            saveTier()

            if let display = response.displayKey {
                licenseDisplayKey = display
                defaults.set(display, forKey: displayKeyKey)
            }

            if let expires = parseISO8601(response.expiresAt) {
                licenseExpiresAt = expires
                defaults.set(expires, forKey: expiresAtKey)
            }

            let now = Date()
            lastValidatedAt = now
            defaults.set(now, forKey: lastValidatedKey)

            if let resolvedActivationID = response.activation?.id ?? activationID {
                saveKeychainString(resolvedActivationID, account: activationIDAccount)
            }

            saveKeychainString(key, account: licenseKeyAccount)
            hasStoredLicense = true
        } catch {
            currentTier = .free
            saveTier()
            billingError = error.localizedDescription
        }
    }

    private func registerActivationIfPossible(key: String, organizationID: String) async -> String? {
        let endpoint = "https://api.polar.sh/v1/customer-portal/license-keys/activate"
        var payload: [String: Any] = [
            "key": key,
            "organization_id": organizationID,
            "label": Host.current().localizedName ?? "DashDock Mac",
            "conditions": ["major_version": majorVersion()],
            "meta": ["platform": "macOS", "app": "DashDock"],
        ]

        if let existingActivation = loadKeychainString(account: activationIDAccount), !existingActivation.isEmpty {
            payload["activation_id"] = existingActivation
        }

        do {
            let data = try await postJSON(urlString: endpoint, payload: payload)
            let response = try JSONDecoder().decode(PolarActivationResponse.self, from: data)
            return response.id
        } catch {
            return loadKeychainString(account: activationIDAccount)
        }
    }

    private func validate(key: String, organizationID: String, activationID: String?) async throws -> PolarValidationResponse {
        let endpoint = "https://api.polar.sh/v1/customer-portal/license-keys/validate"
        var payload: [String: Any] = [
            "key": key,
            "organization_id": organizationID,
            "conditions": ["major_version": majorVersion()],
        ]

        if let activationID, !activationID.isEmpty {
            payload["activation_id"] = activationID
        }

        let data = try await postJSON(urlString: endpoint, payload: payload)
        return try JSONDecoder().decode(PolarValidationResponse.self, from: data)
    }

    private func postJSON(urlString: String, payload: [String: Any]) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw PolarLicenseError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PolarLicenseError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw PolarLicenseError.api(parseErrorMessage(data: data) ?? "HTTP \(http.statusCode)")
        }

        return data
    }

    private func parseErrorMessage(data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct ErrorBody: Decodable {
                let message: String?
                let detail: String?
            }
            let error: ErrorBody?
            let detail: String?
        }

        if let parsed = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return parsed.error?.message ?? parsed.error?.detail ?? parsed.detail
        }

        return String(data: data, encoding: .utf8)
    }

    private func loadTier() {
        if let raw = defaults.string(forKey: tierKey),
           let tier = AppTier(rawValue: raw)
        {
            currentTier = tier
        }
    }

    private func saveTier() {
        defaults.set(currentTier.rawValue, forKey: tierKey)
    }

    private func loadLicenseMetadata() {
        licenseDisplayKey = defaults.string(forKey: displayKeyKey)
        licenseExpiresAt = defaults.object(forKey: expiresAtKey) as? Date
        lastValidatedAt = defaults.object(forKey: lastValidatedKey) as? Date
        hasStoredLicense = loadKeychainString(account: licenseKeyAccount) != nil
    }

    private func saveKeychainString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: licenseService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: licenseService,
                kSecAttrAccount as String: account,
            ]
            let attrs: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(updateQuery as CFDictionary, attrs as CFDictionary)
        }
    }

    private func loadKeychainString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: licenseService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychain(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = iso8601WithFractional.date(from: value) {
            return date
        }
        return iso8601.date(from: value)
    }

    private func majorVersion() -> Int {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        return Int(version.split(separator: ".").first ?? "1") ?? 1
    }

    private var checkoutURL: URL? {
        guard let urlString = bundleValue("POLAR_CHECKOUT_URL") else { return nil }
        return URL(string: urlString)
    }

    private var organizationID: String? {
        bundleValue("POLAR_ORGANIZATION_ID")
    }

    private var expectedBenefitID: String? {
        bundleValue("POLAR_BENEFIT_ID")
    }

    private func bundleValue(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return value
    }

    private let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    private let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct PolarActivationResponse: Decodable {
    let id: String
}

private struct PolarValidationResponse: Decodable {
    struct Activation: Decodable {
        let id: String
    }

    let status: String
    let benefitID: String?
    let displayKey: String?
    let expiresAt: String?
    let activation: Activation?

    enum CodingKeys: String, CodingKey {
        case status
        case benefitID = "benefit_id"
        case displayKey = "display_key"
        case expiresAt = "expires_at"
        case activation
    }
}

enum PolarLicenseError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case api(String)
    case invalidStatus(String)
    case wrongBenefit

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Polar billing is not configured correctly."
        case .invalidResponse:
            return "Invalid response from Polar."
        case .api(let message):
            return message
        case .invalidStatus(let status):
            return "License status is \(status)."
        case .wrongBenefit:
            return "This license key is for a different product."
        }
    }
}
