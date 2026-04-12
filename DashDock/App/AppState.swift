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

// MARK: - Freemium Model

enum AppTier: String, Codable {
    case free
    case pro
}

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    var currentTier: AppTier = .free

    // Free tier limits
    let freeMaxProperties = 1
    let freeRefreshInterval: TimeInterval = 120  // 2 minutes
    let freeWidgetFamilies: Set<String> = ["systemSmall"]

    // Pro tier features
    let proMaxProperties = 10
    let proRefreshInterval: TimeInterval = 30    // 30 seconds
    let proWidgetFamilies: Set<String> = ["systemSmall", "systemMedium", "systemLarge"]

    var isPro: Bool { currentTier == .pro }

    var maxProperties: Int {
        isPro ? proMaxProperties : freeMaxProperties
    }

    var minRefreshInterval: TimeInterval {
        isPro ? proRefreshInterval : freeRefreshInterval
    }

    init() {
        loadTier()
    }

    func upgrade() {
        // TODO: Integrate StoreKit 2 for in-app purchase
        currentTier = .pro
        saveTier()
    }

    func restore() {
        // TODO: Restore purchases via StoreKit 2
    }

    private func loadTier() {
        if let raw = UserDefaults.standard.string(forKey: "app_tier"),
           let tier = AppTier(rawValue: raw) {
            currentTier = tier
        }
    }

    private func saveTier() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: "app_tier")
    }
}
