import Foundation

struct GoogleAccount: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String
    let avatarURL: URL?

    var ga4PropertyID: String?
    var ga4PropertyName: String?
    var adSenseAccountID: String?
    var searchConsoleSiteURL: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GoogleAccount, rhs: GoogleAccount) -> Bool {
        lhs.id == rhs.id
    }
}
