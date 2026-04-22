import SwiftUI

struct AccountsSettingsView: View {
    let authManager: GoogleAuthManager

    var body: some View {
        Form {
            if let account = authManager.currentAccount {
                Section("Connected Account") {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(.headline)
                            Text(account.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let prop = account.ga4PropertyName {
                                Text("Property: \(prop)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Button("Sign Out", role: .destructive) {
                            authManager.signOut()
                        }
                    }
                }
            } else {
                Section {
                    VStack(spacing: 12) {
                        Text("No account connected")
                            .foregroundStyle(.secondary)
                        Button("Sign in with Google") {
                            authManager.signIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
