import SwiftUI

struct UpdateSettingsView: View {
    @EnvironmentObject var updateManager: UpdateManager

    @State private var autoCheck = true
    @State private var autoInstall = true

    var body: some View {
        Form {
            Section("Auto-Update") {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { _, newValue in
                        updateManager.automaticallyChecksForUpdates = newValue
                    }

                Toggle("Automatically download and install updates", isOn: $autoInstall)
                    .onChange(of: autoInstall) { _, newValue in
                        updateManager.automaticallyDownloadsUpdates = newValue
                    }
            }

            Section("Manual") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current version: \(appVersion)")
                            .font(.callout)
                        if let lastCheck = updateManager.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Check for Updates") {
                        updateManager.checkForUpdates()
                    }
                    .disabled(!updateManager.canCheckForUpdates)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How it works")
                        .font(.caption.bold())
                    Text("DashDock uses Sparkle to check for updates from realitech.dev. When a new version is available, it will be downloaded and installed automatically (or you can check manually).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            autoCheck = updateManager.automaticallyChecksForUpdates
            autoInstall = updateManager.automaticallyDownloadsUpdates
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
