import SwiftUI
import Charts

/// Mini sparkline chart for displaying 7-day trends
struct SparklineChart: View {
    let data: [Int]
    let color: Color

    var body: some View {
        if data.isEmpty {
            Rectangle()
                .fill(color.opacity(0.1))
                .frame(height: 28)
        } else {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .foregroundStyle(color)
            .frame(height: 28)
        }
    }
}

/// Trend indicator: arrow + percentage change
struct TrendBadge: View {
    let change: Double?

    var body: some View {
        if let change {
            HStack(spacing: 2) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 7, weight: .bold))
                Text(formatPercent(change))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(change >= 0 ? .green : .red)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                (change >= 0 ? Color.green : Color.red).opacity(0.12),
                in: Capsule()
            )
        }
    }

    private func formatPercent(_ value: Double) -> String {
        if abs(value) >= 100 {
            return String(format: "%+.0f%%", value)
        }
        return String(format: "%+.1f%%", value)
    }
}

// MARK: - Daily Bar Chart (larger, for dashboard section)

struct DailyBarChart: View {
    let title: String
    let data: [CachedGA4Summary.DailyMetric]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if data.isEmpty {
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Date", formatDateLabel(item.date)),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(color.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel()
                            .font(.system(size: 8))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3]))
                        AxisValueLabel()
                            .font(.system(size: 8))
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatDateLabel(_ dateStr: String) -> String {
        // "20260410" → "10/4"
        guard dateStr.count == 8 else { return dateStr }
        let day = String(dateStr.suffix(2))
        let month = String(dateStr.dropFirst(4).prefix(2))
        // Remove leading zeros
        let d = Int(day) ?? 0
        let m = Int(month) ?? 0
        return "\(d)/\(m)"
    }
}
