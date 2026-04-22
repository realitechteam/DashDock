import SwiftUI

struct EnableAdminAPIView: View {
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("One more step")
                    .font(.callout.bold())

                Text("DashDock needs the **Analytics Admin API** to list your properties. Enable it in Google Cloud Console (takes 30 seconds).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                StepRow(number: 1, text: "Click the button below to open Cloud Console")
                StepRow(number: 2, text: "Click **\"Enable\"** on the API page")
                StepRow(number: 3, text: "Come back here and tap **\"Done, load properties\"**")
            }
            .padding(.horizontal, 24)

            Button {
                let url = URL(string: "https://console.cloud.google.com/apis/library/analyticsadmin.googleapis.com")!
                NSWorkspace.shared.open(url)
            } label: {
                HStack {
                    Image(systemName: "safari")
                    Text("Open Google Cloud Console")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Done, load properties")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)

            Button("Skip — enter Property ID manually", action: onSkip)
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption2.bold())
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
