import SwiftUI

struct RealtimeHeroCard: View {
    let data: CachedGA4Realtime

    var body: some View {
        VStack(spacing: 4) {
            Text("\(data.activeUsers)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.blue.gradient)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: data.activeUsers)
            Text("Active Users Right Now")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SummaryCardsView: View {
    let data: CachedGA4Summary

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
            MetricCard(
                title: "Pageviews",
                value: data.pageviews.formattedCompact(),
                icon: "eye.fill",
                color: .purple,
                change: data.pageviewsChange,
                sparklineData: data.dailyPageviews.map(\.value)
            )
            MetricCard(
                title: "Sessions",
                value: data.sessions.formattedCompact(),
                icon: "person.2.fill",
                color: .green,
                change: data.sessionsChange,
                sparklineData: data.dailySessions.map(\.value)
            )
            MetricCard(
                title: "New Users",
                value: data.newUsers.formattedCompact(),
                icon: "person.badge.plus",
                color: .orange,
                change: data.newUsersChange,
                sparklineData: data.dailyNewUsers.map(\.value)
            )
        }
        .padding(.top, 4)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var change: Double? = nil
    var sparklineData: [Int] = []

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .contentTransition(.numericText())

            if change != nil || !sparklineData.isEmpty {
                HStack(spacing: 4) {
                    TrendBadge(change: change)

                    if !sparklineData.isEmpty {
                        SparklineChart(data: sparklineData, color: color)
                            .frame(width: 36)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TopPagesCard: View {
    let pages: [CachedGA4Realtime.PageView]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Pages")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(pages.prefix(5).enumerated()), id: \.offset) { _, page in
                HStack {
                    Text(page.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("\(page.activeUsers)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
    }
}

struct LoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
