import Foundation

struct PolarActivationResponse: Decodable {
    let id: String
}

struct PolarValidationResponse: Decodable {
    struct Activation: Decodable {
        let id: String
    }

    let status: String
    let benefitID: String?
    let displayKey: String?
    let expiresAt: String?
    let activation: Activation?

    enum CodingKeys: String, CodingKey {
        case status
        case benefitID = "benefit_id"
        case displayKey = "display_key"
        case expiresAt = "expires_at"
        case activation
    }
}

enum PolarLicenseError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case api(String)
    case invalidStatus(String)
    case wrongBenefit

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Polar billing is not configured correctly."
        case .invalidResponse:
            return "Invalid response from Polar."
        case .api(let message):
            return message
        case .invalidStatus(let status):
            return "License status is \(status)."
        case .wrongBenefit:
            return "This license key is for a different product."
        }
    }
}
