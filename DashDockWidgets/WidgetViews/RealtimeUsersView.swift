import SwiftUI
import WidgetKit

struct RealtimeUsersView: View {
    let entry: GA4Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            Text("\(entry.activeUsers)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)

            Text("active now")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !entry.isPlaceholder {
                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    // MARK: - Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: big number
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Active now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.activeUsers)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()

                if !entry.isPlaceholder {
                    Text(entry.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)

            if !entry.topPages.isEmpty {
                Divider()

                // Right: top pages
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Pages")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(entry.topPages.prefix(4), id: \.path) { page in
                        HStack {
                            Text(page.path)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text("\(page.activeUsers)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}
