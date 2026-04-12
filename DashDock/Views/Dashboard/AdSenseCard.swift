import SwiftUI
import Charts

// MARK: - AdSense Revenue Card

struct AdSenseCard: View {
    let data: CachedAdSenseRevenue

    private var earningsChange: Double? {
        guard data.yesterdayEarnings > 0 else {
            return data.todayEarnings > 0 ? 100.0 : nil
        }
        return (data.todayEarnings - data.yesterdayEarnings) / data.yesterdayEarnings * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.green)
                Text("AdSense Revenue")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Today's earnings — hero number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(data.todayEarnings.currencyFormatted)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 1) {
                    Text("today")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TrendBadge(change: earningsChange)
                }
            }

            // Sparkline — 7 day earnings
            if !data.dailyEarnings.isEmpty {
                SparklineChart(
                    data: data.dailyEarnings.map { Int($0.earnings * 100) },
                    color: .green
                )
                .frame(height: 24)
            }

            Divider()

            // Metric grid
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 6) {
                AdSenseMiniMetric(label: "Yesterday", value: data.yesterdayEarnings.currencyFormatted)
                AdSenseMiniMetric(label: "7 Days", value: data.last7DaysEarnings.currencyFormatted)
                AdSenseMiniMetric(label: "30 Days", value: data.last30DaysEarnings.currencyFormatted)
                AdSenseMiniMetric(label: "RPM", value: String(format: "$%.2f", data.todayPageviewsRPM))
            }

            // Clicks and impressions row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                    Text("\(data.todayClicks)")
                        .font(.caption.monospacedDigit())
                    Text("clicks")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 9))
                        .foregroundStyle(.purple)
                    Text(data.todayImpressions.formattedCompact())
                        .font(.caption.monospacedDigit())
                    Text("impr.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("CPC")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "$%.2f", data.todayCPC))
                        .font(.caption.bold().monospacedDigit())
                }
            }
        }
        .padding(10)
        .background(.green.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 4)
    }
}

struct AdSenseMiniMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold().monospacedDigit())
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }
}
