import SwiftUI

@main
struct DashDockWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title2)
            Text("DashDock")
                .font(.headline)
            Text("Watch app skeleton")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
