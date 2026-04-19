import Foundation

enum AppCurrency: String, CaseIterable, Codable {
    case vnd = "VND"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .vnd: return "Vietnamese Dong (VND)"
        case .usd: return "US Dollar (USD)"
        case .eur: return "Euro (EUR)"
        case .gbp: return "British Pound (GBP)"
        }
    }

    static func fromStoredCode(_ code: String) -> AppCurrency {
        AppCurrency(rawValue: code.uppercased()) ?? .vnd
    }
}
