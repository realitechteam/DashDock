import SwiftUI

struct RefreshSettingsView: View {
    let syncManager: DataSyncManager
    @State private var realtimeSeconds: Double = 30
    @State private var reportMinutes: Double = 5

    var body: some View {
        Form {
            Section("Realtime Data") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fetch active users every \(Int(realtimeSeconds)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $realtimeSeconds, in: 15...120, step: 15)
                        Text("\(Int(realtimeSeconds))s")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section("Reports") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fetch pageviews/sessions every \(Int(reportMinutes)) minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $reportMinutes, in: 1...30, step: 1)
                        Text("\(Int(reportMinutes))m")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section {
                Button("Apply & Restart") {
                    syncManager.realtimeInterval = realtimeSeconds
                    syncManager.reportInterval = reportMinutes * 60
                    syncManager.startPolling()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            realtimeSeconds = syncManager.realtimeInterval
            reportMinutes = syncManager.reportInterval / 60
        }
    }
}
