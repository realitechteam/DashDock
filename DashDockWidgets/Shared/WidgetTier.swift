import Foundation

enum WidgetTier: String {
    case free
    case pro

    static func current() -> WidgetTier {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let stateURL = appSupport
            .appendingPathComponent("DashDock", isDirectory: true)
            .appendingPathComponent("shared_state.json")
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["appTier"] as? String,
              let tier = WidgetTier(rawValue: raw)
        else {
            return .free
        }
        return tier
    }
}
