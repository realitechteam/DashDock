import Foundation
import WidgetKit

struct GA4Entry: TimelineEntry {
    let date: Date
    let activeUsers: Int
    let topPages: [CachedGA4Realtime.PageView]
    let isPlaceholder: Bool

    static var placeholder: GA4Entry {
        GA4Entry(
            date: Date(),
            activeUsers: 42,
            topPages: [
                CachedGA4Realtime.PageView(path: "/home", activeUsers: 15),
                CachedGA4Realtime.PageView(path: "/blog", activeUsers: 8),
            ],
            isPlaceholder: true
        )
    }
}
