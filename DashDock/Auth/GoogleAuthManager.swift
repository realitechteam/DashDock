import AppKit
import CryptoKit
import Foundation
import Network

@Observable
@MainActor
final class GoogleAuthManager {
    var currentAccount: GoogleAccount?
    var isAuthenticated: Bool { currentAccount != nil }
    var isLoading = false
    var errorMessage: String?

    private let store = SharedDataStore.shared
    private var httpListener: NWListener?
    private var pendingCodeVerifier: String?

    // Loaded from Config.xcconfig via Info.plist
    private var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
    }

    private var clientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_SECRET") as? String ?? ""
    }

    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let userInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo"

    private let scopes = [
        "https://www.googleapis.com/auth/analytics.readonly",
        "https://www.googleapis.com/auth/adsense.readonly",
        "https://www.googleapis.com/auth/webmasters.readonly",
        "openid",
        "email",
        "profile",
    ]

    init() {
        restoreSession()
    }

    // MARK: - Sign In (Local HTTP Server + Browser)

    func signIn() {
        isLoading = true
        errorMessage = nil

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        pendingCodeVerifier = codeVerifier

        // Start local HTTP server to receive the OAuth callback
        startLocalServer(codeVerifier: codeVerifier)

        guard let port = httpListener?.port?.rawValue else {
            isLoading = false
            errorMessage = "Failed to start local auth server"
            return
        }

        let redirectURI = "http://127.0.0.1:\(port)"

        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        guard let authURL = components.url else {
            isLoading = false
            errorMessage = "Failed to build auth URL"
            stopLocalServer()
            return
        }

        // Open system browser
        NSWorkspace.shared.open(authURL)
    }

    // MARK: - Sign Out

    func signOut() {
        guard let account = currentAccount else { return }
        TokenStore.delete(forAccount: account.id)
        currentAccount = nil
        store.clearAll()
    }

    // MARK: - Token Management

    func validAccessToken() async -> String? {
        guard let account = currentAccount,
              var token = TokenStore.load(forAccount: account.id)
        else { return nil }

        if token.isExpired {
            guard let refreshed = await refreshToken(token, accountID: account.id) else {
                return nil
            }
            token = refreshed
        }

        return token.accessToken
    }

    // MARK: - Local HTTP Server

    private func startLocalServer(codeVerifier: String) {
        stopLocalServer()

        do {
            // Use port 0 to let the system assign a free port
            let params = NWParameters.tcp
            let listener = try NWListener(using: params, on: .any)

            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    Task { @MainActor in
                        self?.errorMessage = "Auth server failed"
                        self?.isLoading = false
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { @MainActor in
                    self.handleConnection(connection, codeVerifier: codeVerifier)
                }
            }

            listener.start(queue: .global(qos: .userInitiated))

            // Wait briefly for listener to be ready
            Thread.sleep(forTimeInterval: 0.1)

            self.httpListener = listener
        } catch {
            errorMessage = "Failed to start auth server: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func stopLocalServer() {
        httpListener?.cancel()
        httpListener = nil
    }

    private func handleConnection(_ connection: NWConnection, codeVerifier: String) {
        connection.start(queue: .global(qos: .userInitiated))
        let redirectURI = "http://127.0.0.1:\(httpListener?.port?.rawValue ?? 0)"

        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data,
                  let requestString = String(data: data, encoding: .utf8)
            else {
                connection.cancel()
                return
            }

            // Parse the HTTP request to extract the authorization code
            guard let firstLine = requestString.components(separatedBy: "\r\n").first,
                  let path = firstLine.components(separatedBy: " ").dropFirst().first,
                  let urlComponents = URLComponents(string: "http://localhost\(path)"),
                  let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value
            else {
                // Send error response
                let errorHTML = self.buildHTML(
                    title: "Authentication Failed",
                    body: "No authorization code received. Please try again.",
                    isError: true
                )
                self.sendHTTPResponse(connection: connection, html: errorHTML)
                Task { @MainActor in
                    self.errorMessage = "No authorization code received"
                    self.isLoading = false
                    self.stopLocalServer()
                }
                return
            }

            // Send success response to browser
            let successHTML = self.buildHTML(
                title: "DashDock — Connected!",
                body: "Authentication successful. You can close this tab and return to DashDock.",
                isError: false
            )
            self.sendHTTPResponse(connection: connection, html: successHTML)

            // Exchange code for tokens
            Task { @MainActor in
                await self.exchangeCode(code, codeVerifier: codeVerifier, redirectURI: redirectURI)
                self.stopLocalServer()
            }
        }
    }

    private nonisolated func sendHTTPResponse(connection: NWConnection, html: String) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private nonisolated func buildHTML(title: String, body: String, isError: Bool) -> String {
        let color = isError ? "#e74c3c" : "#27ae60"
        let icon = isError ? "&#10060;" : "&#9989;"
        return """
        <!DOCTYPE html>
        <html>
        <head><title>\(title)</title>
        <style>
            body { font-family: -apple-system, system-ui, sans-serif; display: flex;
                   justify-content: center; align-items: center; min-height: 100vh;
                   margin: 0; background: #1a1a2e; color: #fff; }
            .card { text-align: center; padding: 48px; border-radius: 16px;
                    background: #16213e; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }
            h1 { color: \(color); font-size: 24px; }
            p { color: #a0a0b0; margin-top: 12px; }
            .icon { font-size: 48px; margin-bottom: 16px; }
        </style></head>
        <body><div class="card">
            <div class="icon">\(icon)</div>
            <h1>\(title)</h1>
            <p>\(body)</p>
        </div></body></html>
        """
    }

    // MARK: - Private

    private func restoreSession() {
        if let account = store.loadCurrentAccount(),
           TokenStore.load(forAccount: account.id) != nil {
            currentAccount = account
        }
    }

    private func exchangeCode(_ code: String, codeVerifier: String, redirectURI: String) async {
        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]

        guard let tokenResponse = await postTokenRequest(params) else { return }

        let token = TokenStore(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? "",
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            scopes: scopes
        )

        guard let userInfo = await fetchUserInfo(accessToken: token.accessToken) else {
            errorMessage = "Failed to fetch user info"
            isLoading = false
            return
        }

        let account = GoogleAccount(
            id: userInfo.id,
            email: userInfo.email,
            displayName: userInfo.name,
            avatarURL: URL(string: userInfo.picture ?? "")
        )

        TokenStore.save(token, forAccount: account.id)
        store.saveCurrentAccount(account)

        var accounts = store.loadAccounts()
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            store.saveAccounts(accounts)
        }

        currentAccount = account
        isLoading = false
    }

    private func refreshToken(_ token: TokenStore, accountID: String) async -> TokenStore? {
        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": token.refreshToken,
            "grant_type": "refresh_token",
        ]

        guard let response = await postTokenRequest(params) else {
            signOut()
            return nil
        }

        let newToken = TokenStore(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? token.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            scopes: token.scopes
        )
        TokenStore.save(newToken, forAccount: accountID)
        return newToken
    }

    private func postTokenRequest(_ params: [String: String]) async -> TokenResponse? {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            errorMessage = "Token exchange failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func fetchUserInfo(accessToken: String) async -> GoogleUserInfo? {
        var request = URLRequest(url: URL(string: userInfoEndpoint)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(GoogleUserInfo.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }
}

// MARK: - Models

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct GoogleUserInfo: Decodable {
    let id: String
    let email: String
    let name: String
    let picture: String?
}

// MARK: - Base64URL

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
