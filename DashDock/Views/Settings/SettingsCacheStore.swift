import SwiftUI

@Observable
@MainActor
final class SettingsCacheStore {
    static let shared = SettingsCacheStore()

    private(set) var ga4Accounts: [GA4AccountSummary] = []
    private(set) var ga4AccountID: String?
    private(set) var ga4FetchedAt: Date?

    private(set) var adSenseAccounts: [AdSenseAccount] = []
    private(set) var adSenseAccountID: String?
    private(set) var adSenseFetchedAt: Date?

    func setGA4(accounts: [GA4AccountSummary], for accountID: String?) {
        ga4Accounts = accounts
        ga4AccountID = accountID
        ga4FetchedAt = Date()
    }

    func setAdSense(accounts: [AdSenseAccount], for accountID: String?) {
        adSenseAccounts = accounts
        adSenseAccountID = accountID
        adSenseFetchedAt = Date()
    }

    func ga4Cache(for accountID: String?) -> (accounts: [GA4AccountSummary], fetchedAt: Date)? {
        guard ga4AccountID == accountID, let fetchedAt = ga4FetchedAt else { return nil }
        return (ga4Accounts, fetchedAt)
    }

    func adSenseCache(for accountID: String?) -> (accounts: [AdSenseAccount], fetchedAt: Date)? {
        guard adSenseAccountID == accountID, let fetchedAt = adSenseFetchedAt else { return nil }
        return (adSenseAccounts, fetchedAt)
    }
}
