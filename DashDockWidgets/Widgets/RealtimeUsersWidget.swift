import SwiftUI
import WidgetKit

private let availableFamilies: [WidgetFamily] = {
    if WidgetTier.current() == .pro {
        return [.systemSmall, .systemMedium]
    }
    return [.systemSmall]
}()

struct RealtimeUsersWidget: Widget {
    let kind = "RealtimeUsersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GA4TimelineProvider()) { entry in
            RealtimeUsersView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Realtime Users")
        .description("Shows the current number of active users on your site.")
        .supportedFamilies(availableFamilies)
    }
}
