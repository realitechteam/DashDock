import Foundation

struct TokenStore: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let scopes: [String]

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60) // 1 min buffer
    }

    private static let service = "com.bami.dashdock.oauth"

    static func save(_ token: TokenStore, forAccount accountID: String) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        try? KeychainHelper.save(data, service: service, account: accountID)
    }

    static func load(forAccount accountID: String) -> TokenStore? {
        guard let data = try? KeychainHelper.load(service: service, account: accountID) else { return nil }
        return try? JSONDecoder().decode(TokenStore.self, from: data)
    }

    static func delete(forAccount accountID: String) {
        KeychainHelper.delete(service: service, account: accountID)
    }
}
