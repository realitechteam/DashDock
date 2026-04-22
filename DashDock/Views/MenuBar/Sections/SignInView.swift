import SwiftUI

struct SignInView: View {
    let authManager: GoogleAuthManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text("DashDock")
                .font(.title2.bold())

            Text("Monitor Google Analytics, AdSense & Search Console right from your Desktop.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                authManager.signIn()
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(authManager.isLoading)

            if authManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}
