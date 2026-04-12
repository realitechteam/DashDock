import WidgetKit

struct GA4TimelineProvider: TimelineProvider {
    private let store = SharedDataStore.shared

    typealias Entry = GA4Entry

    func placeholder(in context: Context) -> GA4Entry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (GA4Entry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GA4Entry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> GA4Entry {
        if let cached = store.loadGA4Realtime() {
            return GA4Entry(
                date: Date(),
                activeUsers: cached.activeUsers,
                topPages: cached.topPages,
                isPlaceholder: false
            )
        }
        return GA4Entry(
            date: Date(),
            activeUsers: 0,
            topPages: [],
            isPlaceholder: false
        )
    }
}
