import Foundation
import WidgetKit

@Observable
@MainActor
final class DataSyncManager {
    var ga4Realtime: CachedGA4Realtime?
    var ga4Summary: CachedGA4Summary?
    var isRefreshing = false
    var lastError: String?

    private var ga4Client: GA4Client?
    private let store = SharedDataStore.shared
    private var realtimeTimer: Timer?
    private var reportTimer: Timer?

    var realtimeInterval: TimeInterval = 30
    var reportInterval: TimeInterval = 300

    func configure(apiClient: APIClient) {
        self.ga4Client = GA4Client(apiClient: apiClient)
        loadCachedData()
    }

    // MARK: - Start / Stop

    func startPolling() {
        stopPolling()

        realtimeTimer = Timer.scheduledTimer(withTimeInterval: realtimeInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchRealtime()
            }
        }

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchReports()
            }
        }

        // Fetch immediately
        Task {
            await fetchRealtime()
            await fetchReports()
        }
    }

    func stopPolling() {
        realtimeTimer?.invalidate()
        realtimeTimer = nil
        reportTimer?.invalidate()
        reportTimer = nil
    }

    // MARK: - Manual Refresh

    func refreshAll() async {
        await fetchRealtime()
        await fetchReports()
    }

    // MARK: - Fetch

    private func fetchRealtime() async {
        guard let client = ga4Client,
              let propertyID = store.loadCurrentAccount()?.ga4PropertyID
        else { return }

        do {
            let response = try await client.fetchRealtimeReport(propertyID: propertyID)
            let cached = CachedGA4Realtime(
                activeUsers: response.activeUsers,
                topPages: response.topPages.map {
                    CachedGA4Realtime.PageView(path: $0.path, activeUsers: $0.activeUsers)
                },
                timestamp: Date()
            )
            ga4Realtime = cached
            store.saveGA4Realtime(cached)
            WidgetCenter.shared.reloadAllTimelines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchReports() async {
        guard let client = ga4Client,
              let propertyID = store.loadCurrentAccount()?.ga4PropertyID
        else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let dailyResponse = try await client.fetchDailySummary(propertyID: propertyID)
            let topPagesResponse = try await client.fetchTopPages(propertyID: propertyID)

            let totals = dailyResponse.totalMetrics
            let dailyPageviews = dailyResponse.rowData.map {
                CachedGA4Summary.DailyMetric(
                    date: $0.dimensions.first ?? "",
                    value: Int($0.metrics.first ?? "0") ?? 0
                )
            }
            let topPages = topPagesResponse.rowData.map {
                CachedGA4Summary.PageSummary(
                    path: $0.dimensions.first ?? "",
                    pageviews: Int($0.metrics.first ?? "0") ?? 0
                )
            }

            let cached = CachedGA4Summary(
                pageviews: totals.count > 0 ? totals[0] : 0,
                sessions: totals.count > 1 ? totals[1] : 0,
                newUsers: totals.count > 2 ? totals[2] : 0,
                topPages: topPages,
                dailyPageviews: dailyPageviews,
                timestamp: Date()
            )
            ga4Summary = cached
            store.saveGA4Summary(cached)
            WidgetCenter.shared.reloadAllTimelines()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func loadCachedData() {
        ga4Realtime = store.loadGA4Realtime()
        ga4Summary = store.loadGA4Summary()
    }
}
