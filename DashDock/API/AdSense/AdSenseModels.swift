import Foundation

// MARK: - Request helpers

struct AdSenseDateRange {
    let startDate: String  // YYYY-MM-DD
    let endDate: String    // YYYY-MM-DD
}

// MARK: - Response Models

struct AdSenseAccountsResponse: Decodable {
    let accounts: [AdSenseAccount]?
    let nextPageToken: String?
}

struct AdSenseAccount: Decodable, Identifiable, Hashable {
    let name: String        // "accounts/pub-1234567890"
    let displayName: String
    let state: String?      // "READY"

    var id: String { name }

    /// Extracts "pub-1234567890" from "accounts/pub-1234567890"
    var accountID: String {
        name.replacingOccurrences(of: "accounts/", with: "")
    }
}

struct AdSenseReportResponse: Decodable {
    let headers: [AdSenseHeader]?
    let rows: [AdSenseRow]?
    let totals: AdSenseRowCells?
    let totalMatchedRows: String?
}

struct AdSenseHeader: Decodable {
    let name: String
    let type: String?  // "DIMENSION", "METRIC_TALLY", "METRIC_RATIO", "METRIC_CURRENCY"
}

struct AdSenseRow: Decodable {
    let cells: [AdSenseCell]
}

struct AdSenseRowCells: Decodable {
    let cells: [AdSenseCell]
}

struct AdSenseCell: Decodable {
    let value: String?
}
