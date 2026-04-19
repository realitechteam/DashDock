import Foundation

extension Int {
    var compactFormatted: String {
        formattedCompact()
    }

    func formattedCompact() -> String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

extension Double {
    var currencyFormatted: String {
        let code = SharedDataStore.shared.loadPreferredCurrency()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        if code == "VND" {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        }
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }

    var percentFormatted: String {
        String(format: "%.1f%%", self * 100)
    }

    var positionFormatted: String {
        String(format: "%.1f", self)
    }
}
