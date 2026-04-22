import Foundation

enum PolarConfig {
    static var checkoutURL: URL? {
        guard let urlString = bundleValue("POLAR_CHECKOUT_URL") else { return nil }
        return URL(string: urlString)
    }

    static var organizationID: String? {
        bundleValue("POLAR_ORGANIZATION_ID")
    }

    static var expectedBenefitID: String? {
        bundleValue("POLAR_BENEFIT_ID")
    }

    private static func bundleValue(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return value
    }
}
