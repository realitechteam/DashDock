import Foundation

final class SharedDataStore {
    static let shared = SharedDataStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let ga4RealtimeKey = "ga4_realtime"
    private let ga4SummaryKey = "ga4_summary"
    private let adSenseRevenueKey = "adsense_revenue"
    private let searchConsoleKey = "search_console"
    private let currentAccountKey = "current_account"
    private let accountsKey = "accounts"

    init() {
        // Use standard UserDefaults for sideload; switch to App Group for App Store
        self.defaults = .standard

        // Also write to shared file for widget extension
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sharedDir = appSupport.appendingPathComponent("DashDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)
    }

    // MARK: - GA4 Realtime

    func saveGA4Realtime(_ data: CachedGA4Realtime) {
        save(data, forKey: ga4RealtimeKey)
    }

    func loadGA4Realtime() -> CachedGA4Realtime? {
        load(CachedGA4Realtime.self, forKey: ga4RealtimeKey)
    }

    // MARK: - GA4 Summary

    func saveGA4Summary(_ data: CachedGA4Summary) {
        save(data, forKey: ga4SummaryKey)
    }

    func loadGA4Summary() -> CachedGA4Summary? {
        load(CachedGA4Summary.self, forKey: ga4SummaryKey)
    }

    // MARK: - AdSense

    func saveAdSenseRevenue(_ data: CachedAdSenseRevenue) {
        save(data, forKey: adSenseRevenueKey)
    }

    func loadAdSenseRevenue() -> CachedAdSenseRevenue? {
        load(CachedAdSenseRevenue.self, forKey: adSenseRevenueKey)
    }

    // MARK: - Search Console

    func saveSearchConsole(_ data: CachedSearchConsole) {
        save(data, forKey: searchConsoleKey)
    }

    func loadSearchConsole() -> CachedSearchConsole? {
        load(CachedSearchConsole.self, forKey: searchConsoleKey)
    }

    // MARK: - Account

    func saveCurrentAccount(_ account: GoogleAccount) {
        save(account, forKey: currentAccountKey)
    }

    func loadCurrentAccount() -> GoogleAccount? {
        load(GoogleAccount.self, forKey: currentAccountKey)
    }

    func saveAccounts(_ accounts: [GoogleAccount]) {
        save(accounts, forKey: accountsKey)
    }

    func loadAccounts() -> [GoogleAccount] {
        load([GoogleAccount].self, forKey: accountsKey) ?? []
    }

    // MARK: - Helpers

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func clearAll() {
        [ga4RealtimeKey, ga4SummaryKey, adSenseRevenueKey, searchConsoleKey, currentAccountKey, accountsKey].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
