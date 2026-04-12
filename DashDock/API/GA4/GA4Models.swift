import Foundation

// MARK: - Admin API Models (Account Summaries / Property Listing)

struct GA4AccountSummariesResponse: Decodable {
    let accountSummaries: [GA4AccountSummary]?
    let nextPageToken: String?
}

struct GA4AccountSummary: Decodable, Identifiable {
    let name: String            // "accountSummaries/12345"
    let account: String         // "accounts/12345"
    let displayName: String
    let propertySummaries: [GA4PropertySummary]?

    var id: String { account }
}

struct GA4PropertySummary: Decodable, Identifiable, Hashable {
    let property: String        // "properties/123456789"
    let displayName: String
    let propertyType: String?   // "PROPERTY_TYPE_ORDINARY", etc.
    let parent: String?         // "accounts/12345"

    var id: String { property }

    /// Extracts the numeric property ID from "properties/123456789"
    var propertyID: String {
        property.replacingOccurrences(of: "properties/", with: "")
    }
}

// MARK: - Request Models

struct GA4RealtimeRequest: Encodable {
    let metrics: [GA4Metric]
    let dimensions: [GA4Dimension]?
    let metricAggregations: [String]?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case metrics, dimensions, metricAggregations, limit
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metrics, forKey: .metrics)
        try container.encodeIfPresent(dimensions, forKey: .dimensions)
        try container.encodeIfPresent(metricAggregations, forKey: .metricAggregations)
        try container.encodeIfPresent(limit, forKey: .limit)
    }
}

struct GA4ReportRequest: Encodable {
    let dateRanges: [GA4DateRange]
    let metrics: [GA4Metric]
    let dimensions: [GA4Dimension]?
    let metricAggregations: [String]?
    let orderBys: [GA4OrderBy]?
    let limit: Int?
}

struct GA4Metric: Codable {
    let name: String
}

struct GA4Dimension: Codable {
    let name: String
}

struct GA4DateRange: Codable {
    let startDate: String
    let endDate: String
}

struct GA4OrderBy: Encodable {
    struct DimensionOrder: Encodable {
        let dimensionName: String
    }
    struct MetricOrder: Encodable {
        let metricName: String
    }

    let dimension: DimensionOrder?
    let metric: MetricOrder?
    let desc: Bool

    init(dimension: DimensionOrder? = nil, metric: MetricOrder? = nil, desc: Bool = false) {
        self.dimension = dimension
        self.metric = metric
        self.desc = desc
    }
}

// MARK: - Response Models

struct GA4RealtimeResponse: Decodable {
    let rows: [GA4Row]?
    let totals: [GA4Row]?
    let rowCount: Int?

    var activeUsers: Int {
        // Try totals first (requires metricAggregations in request)
        if let totals, let first = totals.first,
           let value = first.metricValues?.first?.value,
           let count = Int(value) {
            return count
        }
        // Fallback: sum from all rows
        guard let rows else { return 0 }
        return rows.compactMap { row -> Int? in
            guard let val = row.metricValues?.first?.value else { return nil }
            return Int(val)
        }.reduce(0, +)
    }

    var topPages: [(path: String, activeUsers: Int)] {
        guard let rows else { return [] }
        return rows.compactMap { row in
            guard let dim = row.dimensionValues?.first?.value,
                  let metric = row.metricValues?.first?.value,
                  let count = Int(metric)
            else { return nil }
            return (path: dim, activeUsers: count)
        }
    }
}

struct GA4ReportResponse: Decodable {
    let rows: [GA4Row]?
    let totals: [GA4Row]?
    let rowCount: Int?

    /// Total metrics for the first (current) date range
    var totalMetrics: [Int] {
        guard let totals, let first = totals.first else { return [] }
        return first.metricValues?.compactMap { Int($0.value) } ?? []
    }

    /// Total metrics for the second (previous) date range — used for comparison
    var prevTotalMetrics: [Int] {
        guard let totals, totals.count > 1 else { return [] }
        return totals[1].metricValues?.compactMap { Int($0.value) } ?? []
    }

    /// Row data — filters to first date range only when multiple ranges used
    var rowData: [(dimensions: [String], metrics: [String])] {
        guard let rows else { return [] }
        return rows.compactMap { row in
            let dims = row.dimensionValues?.map(\.value) ?? []
            let mets = row.metricValues?.map(\.value) ?? []
            // When using multiple date ranges, rows include a "dateRange" dimension
            // Filter to "date_range_0" (current period) only
            if dims.contains("date_range_1") { return nil }
            let cleanDims = dims.filter { $0 != "date_range_0" }
            return (dimensions: cleanDims, metrics: mets)
        }
    }
}

struct GA4Row: Decodable {
    let dimensionValues: [GA4Value]?
    let metricValues: [GA4Value]?
}

struct GA4Value: Decodable {
    let value: String
}
