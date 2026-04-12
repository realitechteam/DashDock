import SwiftUI

struct MenuBarLabel: View {
    let syncManager: DataSyncManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.xaxis")
            if let activeUsers = syncManager.ga4Realtime?.activeUsers, activeUsers > 0 {
                Text("\(activeUsers)")
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }
}
