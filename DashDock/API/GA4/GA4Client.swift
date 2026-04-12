import Foundation

final class GA4Client {
    private let apiClient: APIClient
    private let rateLimiter = RateLimiter(maxRequestsPerMinute: 10)
    private let baseURL = "https://analyticsdata.googleapis.com/v1beta"
    private let adminURL = "https://analyticsadmin.googleapis.com/v1beta"

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List Properties (Admin API)

    func listAccountSummaries() async throws -> [GA4AccountSummary] {
        var allSummaries: [GA4AccountSummary] = []
        var pageToken: String? = nil

        repeat {
            var urlStr = "\(adminURL)/accountSummaries?pageSize=50"
            if let token = pageToken {
                urlStr += "&pageToken=\(token)"
            }
            let response: GA4AccountSummariesResponse = try await apiClient.get(url: URL(string: urlStr)!)
            allSummaries.append(contentsOf: response.accountSummaries ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allSummaries
    }

    // MARK: - Realtime

    func fetchRealtimeReport(propertyID: String) async throws -> GA4RealtimeResponse {
        guard await rateLimiter.tryAcquire() else {
            let wait = await rateLimiter.secondsUntilAvailable()
            throw APIError.rateLimited(retryAfterSeconds: Int(wait))
        }

        let url = URL(string: "\(baseURL)/properties/\(propertyID):runRealtimeReport")!
        let request = GA4RealtimeRequest(
            metrics: [
                GA4Metric(name: "activeUsers"),
            ],
            dimensions: [
                GA4Dimension(name: "unifiedScreenName"),
            ],
            metricAggregations: ["TOTAL"],
            limit: 10
        )
        return try await apiClient.post(url: url, body: request)
    }

    // MARK: - Reports

    func fetchDailySummary(propertyID: String, days: Int = 7) async throws -> GA4ReportResponse {
        guard await rateLimiter.tryAcquire() else {
            let wait = await rateLimiter.secondsUntilAvailable()
            throw APIError.rateLimited(retryAfterSeconds: Int(wait))
        }

        let url = URL(string: "\(baseURL)/properties/\(propertyID):runReport")!
        let request = GA4ReportRequest(
            dateRanges: [
                GA4DateRange(startDate: "\(days)daysAgo", endDate: "today"),
            ],
            metrics: [
                GA4Metric(name: "screenPageViews"),
                GA4Metric(name: "sessions"),
                GA4Metric(name: "newUsers"),
            ],
            dimensions: [
                GA4Dimension(name: "date"),
            ],
            metricAggregations: ["TOTAL"],
            orderBys: [
                GA4OrderBy(dimension: GA4OrderBy.DimensionOrder(dimensionName: "date")),
            ],
            limit: days + 1
        )
        return try await apiClient.post(url: url, body: request)
    }

    func fetchTopPages(propertyID: String, days: Int = 1) async throws -> GA4ReportResponse {
        guard await rateLimiter.tryAcquire() else {
            let wait = await rateLimiter.secondsUntilAvailable()
            throw APIError.rateLimited(retryAfterSeconds: Int(wait))
        }

        let url = URL(string: "\(baseURL)/properties/\(propertyID):runReport")!
        let request = GA4ReportRequest(
            dateRanges: [
                GA4DateRange(startDate: "\(days)daysAgo", endDate: "today"),
            ],
            metrics: [
                GA4Metric(name: "screenPageViews"),
            ],
            dimensions: [
                GA4Dimension(name: "pagePath"),
            ],
            metricAggregations: nil,
            orderBys: [
                GA4OrderBy(metric: GA4OrderBy.MetricOrder(metricName: "screenPageViews"), desc: true),
            ],
            limit: 10
        )
        return try await apiClient.post(url: url, body: request)
    }
}
