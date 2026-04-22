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
