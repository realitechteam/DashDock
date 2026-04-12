import Foundation

struct CachedGA4Realtime: Codable {
    let activeUsers: Int
    let topPages: [PageView]
    let timestamp: Date

    struct PageView: Codable {
        let path: String
        let activeUsers: Int
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 120
    }
}

struct CachedGA4Summary: Codable {
    let pageviews: Int
    let sessions: Int
    let newUsers: Int
    // Previous period for comparison
    let prevPageviews: Int
    let prevSessions: Int
    let prevNewUsers: Int
    let topPages: [PageSummary]
    let dailyPageviews: [DailyMetric]
    let dailySessions: [DailyMetric]
    let dailyNewUsers: [DailyMetric]
    let timestamp: Date

    struct PageSummary: Codable {
        let path: String
        let pageviews: Int
    }

    struct DailyMetric: Codable, Identifiable {
        let date: String
        let value: Int
        var id: String { date }
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 600
    }

    // Percentage change helpers
    var pageviewsChange: Double? { percentChange(current: pageviews, previous: prevPageviews) }
    var sessionsChange: Double? { percentChange(current: sessions, previous: prevSessions) }
    var newUsersChange: Double? { percentChange(current: newUsers, previous: prevNewUsers) }

    private func percentChange(current: Int, previous: Int) -> Double? {
        guard previous > 0 else { return current > 0 ? 100.0 : nil }
        return Double(current - previous) / Double(previous) * 100.0
    }
}

struct CachedAdSenseRevenue: Codable {
    let todayEarnings: Double
    let yesterdayEarnings: Double
    let last7DaysEarnings: Double
    let last30DaysEarnings: Double
    let todayClicks: Int
    let todayImpressions: Int
    let todayPageviewsRPM: Double
    let todayCPC: Double
    let dailyEarnings: [DailyEarning]
    let timestamp: Date

    struct DailyEarning: Codable, Identifiable {
        let date: String
        let earnings: Double
        var id: String { date }
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 600
    }
}

struct CachedSearchConsole: Codable {
    let totalClicks: Int
    let totalImpressions: Int
    let averageCTR: Double
    let averagePosition: Double
    let topQueries: [QueryData]
    let topPages: [PageData]
    let dailyClicks: [DailyClicks]
    let timestamp: Date

    struct QueryData: Codable, Identifiable {
        let query: String
        let clicks: Int
        let impressions: Int
        let ctr: Double
        let position: Double
        var id: String { query }
    }

    struct PageData: Codable, Identifiable {
        let page: String
        let clicks: Int
        let impressions: Int
        var id: String { page }
    }

    struct DailyClicks: Codable, Identifiable {
        let date: String
        let clicks: Int
        var id: String { date }
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 1200
    }
}
