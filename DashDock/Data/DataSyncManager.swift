import Foundation
import WidgetKit

@Observable
@MainActor
final class DataSyncManager {
    var ga4Realtime: CachedGA4Realtime?
    var ga4Summary: CachedGA4Summary?
    var adSenseRevenue: CachedAdSenseRevenue?
    var isRefreshing = false
    var lastError: String?

    private var ga4Client: GA4Client?
    private var adSenseClient: AdSenseClient?
    private let store = SharedDataStore.shared
    private var realtimeTimer: Timer?
    private var reportTimer: Timer?
    private var adSenseTimer: Timer?

    var realtimeInterval: TimeInterval = 30
    var reportInterval: TimeInterval = 300
    var adSenseInterval: TimeInterval = 300  // 5 minutes

    private var shouldShowAds: Bool {
        SubscriptionManager.shared.currentTier == .free
    }

    func configure(apiClient: APIClient) {
        self.ga4Client = GA4Client(apiClient: apiClient)
        self.adSenseClient = AdSenseClient(apiClient: apiClient)
        loadCachedData()
    }

    // MARK: - Start / Stop

    func startPolling() {
        stopPolling()

        if !shouldShowAds {
            adSenseRevenue = nil
        }

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

        if shouldShowAds {
            adSenseTimer = Timer.scheduledTimer(withTimeInterval: adSenseInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchAdSense()
                }
            }
        }

        // Fetch immediately
        Task {
            await fetchRealtime()
            await fetchReports()
            if shouldShowAds {
                await fetchAdSense()
            }
        }
    }

    func stopPolling() {
        realtimeTimer?.invalidate()
        realtimeTimer = nil
        reportTimer?.invalidate()
        reportTimer = nil
        adSenseTimer?.invalidate()
        adSenseTimer = nil
    }

    // MARK: - Manual Refresh

    func refreshAll() async {
        await fetchRealtime()
        await fetchReports()
        if shouldShowAds {
            await fetchAdSense()
        }
    }

    // MARK: - Fetch GA4

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
            let prevTotals = dailyResponse.prevTotalMetrics

            let currentRows = dailyResponse.rowData
            var dailyPageviews: [CachedGA4Summary.DailyMetric] = []
            var dailySessions: [CachedGA4Summary.DailyMetric] = []
            var dailyNewUsers: [CachedGA4Summary.DailyMetric] = []

            for row in currentRows {
                let date = row.dimensions.first ?? ""
                let pvVal = Int(row.metrics.count > 0 ? row.metrics[0] : "0") ?? 0
                let sessVal = Int(row.metrics.count > 1 ? row.metrics[1] : "0") ?? 0
                let nuVal = Int(row.metrics.count > 2 ? row.metrics[2] : "0") ?? 0

                dailyPageviews.append(.init(date: date, value: pvVal))
                dailySessions.append(.init(date: date, value: sessVal))
                dailyNewUsers.append(.init(date: date, value: nuVal))
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
                prevPageviews: prevTotals.count > 0 ? prevTotals[0] : 0,
                prevSessions: prevTotals.count > 1 ? prevTotals[1] : 0,
                prevNewUsers: prevTotals.count > 2 ? prevTotals[2] : 0,
                topPages: topPages,
                dailyPageviews: dailyPageviews,
                dailySessions: dailySessions,
                dailyNewUsers: dailyNewUsers,
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

    // MARK: - Fetch AdSense

    private func fetchAdSense() async {
        guard let client = adSenseClient,
              let accountName = store.loadCurrentAccount()?.adSenseAccountName
        else { return }

        do {
            // Fetch today's summary
            let todayReport = try await client.fetchTodaySummary(accountName: accountName)
            let todayTotals = parseTotals(todayReport)

            // Fetch yesterday for comparison
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let yDateStr = dateString(yesterday)
            let yesterdayReport = try await client.fetchReport(
                accountName: accountName,
                startDate: AdSenseDateRange(startDate: yDateStr, endDate: yDateStr)
            )
            let yesterdayTotals = parseTotals(yesterdayReport)

            // Fetch 7-day and 30-day summaries
            let report7d = try await client.fetchRangeSummary(accountName: accountName, days: 7)
            let report30d = try await client.fetchRangeSummary(accountName: accountName, days: 30)

            let earnings7d = parseEarnings(report7d)
            let earnings30d = parseEarnings(report30d)

            // Fetch daily breakdown for sparkline
            let dailyReport = try await client.fetchDailyReport(accountName: accountName, days: 7)
            let dailyEarnings = parseDailyEarnings(dailyReport)

            let cached = CachedAdSenseRevenue(
                todayEarnings: todayTotals.earnings,
                yesterdayEarnings: yesterdayTotals.earnings,
                last7DaysEarnings: earnings7d,
                last30DaysEarnings: earnings30d,
                todayClicks: todayTotals.clicks,
                todayImpressions: todayTotals.impressions,
                todayPageviewsRPM: todayTotals.rpm,
                todayCPC: todayTotals.cpc,
                dailyEarnings: dailyEarnings,
                timestamp: Date()
            )
            adSenseRevenue = cached
            store.saveAdSenseRevenue(cached)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Don't overwrite lastError from GA4 — AdSense errors are secondary
            print("[AdSense] Error: \(error.localizedDescription)")
        }
    }

    // MARK: - AdSense Parse Helpers

    private struct AdSenseTotals {
        let earnings: Double
        let clicks: Int
        let impressions: Int
        let rpm: Double
        let cpc: Double
    }

    private func parseTotals(_ report: AdSenseReportResponse) -> AdSenseTotals {
        let headers = report.headers ?? []
        let cells = report.totals?.cells ?? []

        var earnings = 0.0, clicks = 0, impressions = 0, rpm = 0.0, cpc = 0.0

        for (i, header) in headers.enumerated() where i < cells.count {
            let val = cells[i].value ?? "0"
            switch header.name {
            case "ESTIMATED_EARNINGS":
                earnings = Double(val) ?? 0
            case "CLICKS":
                clicks = Int(val) ?? 0
            case "IMPRESSIONS":
                impressions = Int(val) ?? 0
            case "PAGE_VIEWS_RPM":
                rpm = Double(val) ?? 0
            case "COST_PER_CLICK":
                cpc = Double(val) ?? 0
            default:
                break
            }
        }

        return AdSenseTotals(earnings: earnings, clicks: clicks, impressions: impressions, rpm: rpm, cpc: cpc)
    }

    private func parseEarnings(_ report: AdSenseReportResponse) -> Double {
        let cells = report.totals?.cells ?? []
        return Double(cells.first?.value ?? "0") ?? 0
    }

    private func parseDailyEarnings(_ report: AdSenseReportResponse) -> [CachedAdSenseRevenue.DailyEarning] {
        let headers = report.headers ?? []
        let rows = report.rows ?? []

        let dateIdx = headers.firstIndex { $0.name == "DATE" } ?? 0
        let earningsIdx = headers.firstIndex { $0.name == "ESTIMATED_EARNINGS" } ?? 1

        return rows.compactMap { row in
            guard dateIdx < row.cells.count, earningsIdx < row.cells.count else { return nil }
            let date = row.cells[dateIdx].value ?? ""
            let earnings = Double(row.cells[earningsIdx].value ?? "0") ?? 0
            return CachedAdSenseRevenue.DailyEarning(date: date, earnings: earnings)
        }
    }

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    // MARK: - Cache

    private func loadCachedData() {
        ga4Realtime = store.loadGA4Realtime()
        ga4Summary = store.loadGA4Summary()
        adSenseRevenue = store.loadAdSenseRevenue()
    }
}
