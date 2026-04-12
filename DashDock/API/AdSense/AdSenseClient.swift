import Foundation

final class AdSenseClient {
    private let apiClient: APIClient
    private let rateLimiter = RateLimiter(maxRequestsPerMinute: 10)
    private let baseURL = "https://adsense.googleapis.com/v2"

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List Accounts

    func listAccounts() async throws -> [AdSenseAccount] {
        guard await rateLimiter.tryAcquire() else {
            let wait = await rateLimiter.secondsUntilAvailable()
            throw APIError.rateLimited(retryAfterSeconds: Int(wait))
        }

        let url = URL(string: "\(baseURL)/accounts")!
        let response: AdSenseAccountsResponse = try await apiClient.get(url: url)
        return response.accounts ?? []
    }

    // MARK: - Generate Report

    /// Fetch AdSense report for a given account and date range
    /// Metrics: ESTIMATED_EARNINGS, CLICKS, IMPRESSIONS, PAGE_VIEWS_RPM, COST_PER_CLICK
    func fetchReport(
        accountName: String,
        startDate: AdSenseDateRange,
        metrics: [String] = ["ESTIMATED_EARNINGS", "CLICKS", "IMPRESSIONS", "PAGE_VIEWS_RPM", "COST_PER_CLICK"],
        dimensions: [String] = [],
        orderBy: String? = nil,
        limit: Int? = nil
    ) async throws -> AdSenseReportResponse {
        guard await rateLimiter.tryAcquire() else {
            let wait = await rateLimiter.secondsUntilAvailable()
            throw APIError.rateLimited(retryAfterSeconds: Int(wait))
        }

        // Build URL with query params (AdSense v2 uses GET with query params)
        var components = URLComponents(string: "\(baseURL)/\(accountName)/reports:generate")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "dateRange", value: "CUSTOM"),
            URLQueryItem(name: "startDate.year", value: yearComponent(startDate.startDate)),
            URLQueryItem(name: "startDate.month", value: monthComponent(startDate.startDate)),
            URLQueryItem(name: "startDate.day", value: dayComponent(startDate.startDate)),
            URLQueryItem(name: "endDate.year", value: yearComponent(startDate.endDate)),
            URLQueryItem(name: "endDate.month", value: monthComponent(startDate.endDate)),
            URLQueryItem(name: "endDate.day", value: dayComponent(startDate.endDate)),
        ]

        for metric in metrics {
            queryItems.append(URLQueryItem(name: "metrics", value: metric))
        }
        for dim in dimensions {
            queryItems.append(URLQueryItem(name: "dimensions", value: dim))
        }
        if let orderBy {
            queryItems.append(URLQueryItem(name: "orderBy", value: "+\(orderBy)"))
        }
        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        components.queryItems = queryItems
        return try await apiClient.get(url: components.url!)
    }

    // MARK: - Convenience: Today's summary

    func fetchTodaySummary(accountName: String) async throws -> AdSenseReportResponse {
        let today = dateString(Date())
        return try await fetchReport(
            accountName: accountName,
            startDate: AdSenseDateRange(startDate: today, endDate: today)
        )
    }

    /// Fetch daily breakdown for last N days
    func fetchDailyReport(accountName: String, days: Int = 7) async throws -> AdSenseReportResponse {
        let end = dateString(Date())
        let start = dateString(Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date())!)
        return try await fetchReport(
            accountName: accountName,
            startDate: AdSenseDateRange(startDate: start, endDate: end),
            metrics: ["ESTIMATED_EARNINGS", "CLICKS", "IMPRESSIONS"],
            dimensions: ["DATE"]
        )
    }

    /// Fetch summary for a date range (e.g., last 7 days, last 30 days)
    func fetchRangeSummary(accountName: String, days: Int) async throws -> AdSenseReportResponse {
        let end = dateString(Date())
        let start = dateString(Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date())!)
        return try await fetchReport(
            accountName: accountName,
            startDate: AdSenseDateRange(startDate: start, endDate: end),
            metrics: ["ESTIMATED_EARNINGS"]
        )
    }

    // MARK: - Date helpers

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func yearComponent(_ dateStr: String) -> String {
        String(dateStr.prefix(4))
    }

    private func monthComponent(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        return parts.count > 1 ? String(Int(parts[1])!) : "1"
    }

    private func dayComponent(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        return parts.count > 2 ? String(Int(parts[2])!) : "1"
    }
}
