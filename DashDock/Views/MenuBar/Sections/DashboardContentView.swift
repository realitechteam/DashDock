import SwiftUI

struct DashboardContentView: View {
    let syncManager: DataSyncManager

    var body: some View {
        VStack(spacing: 8) {
            if let realtime = syncManager.ga4Realtime {
                RealtimeHeroCard(data: realtime)
            } else {
                LoadingCard(title: "Loading realtime data...")
            }

            if let summary = syncManager.ga4Summary {
                SummaryCardsView(data: summary)

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

            if SubscriptionManager.shared.currentTier == .free,
               let adsense = syncManager.adSenseRevenue {
                AdSenseCard(data: adsense)
            }

            if let realtime = syncManager.ga4Realtime, !realtime.topPages.isEmpty {
                TopPagesCard(pages: realtime.topPages)
            }
        }
    }
}
