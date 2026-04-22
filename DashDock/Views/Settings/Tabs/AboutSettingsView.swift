import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text("DashDock").font(.title.bold())

            Text("v\(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Real-time Google Analytics, AdSense & Search Console monitoring for your Mac Desktop.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider().padding(.horizontal, 60)

            VStack(spacing: 8) {
                Text("Realitech Team").font(.headline)

                Link(destination: URL(string: "https://realitech.dev")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("realitech.dev")
                    }
                    .font(.callout)
                }

                Link(destination: URL(string: "mailto:partner@realitech.dev")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                        Text("partner@realitech.dev")
                    }
                    .font(.callout)
                }

                HStack(spacing: 4) {
                    Image(systemName: "phone")
                    Text("+84 345 678 462")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Made with ♥ in Vietnam")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
