import Foundation

final class APIClient {
    private let authManager: GoogleAuthManager
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    init(authManager: GoogleAuthManager) {
        self.authManager = authManager
    }

    func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        try await authorize(&request)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    func post<B: Encodable, T: Decodable>(url: URL, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        try await authorize(&request)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func authorize(_ request: inout URLRequest) async throws {
        guard let token = await authManager.validAccessToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            let detail = parseGoogleError(data)
            throw APIError.forbidden(detail: detail)
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Int.init) ?? 60
            throw APIError.rateLimited(retryAfterSeconds: retryAfter)
        default:
            let detail = parseGoogleError(data)
            throw APIError.httpError(statusCode: http.statusCode, detail: detail)
        }
    }

    /// Parse Google API error response: {"error": {"message": "...", "status": "..."}}
    private func parseGoogleError(_ data: Data) -> String {
        struct GoogleError: Decodable {
            struct Inner: Decodable {
                let message: String?
                let status: String?
            }
            let error: Inner?
        }
        if let parsed = try? JSONDecoder().decode(GoogleError.self, from: data),
           let msg = parsed.error?.message {
            return msg
        }
        return String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown error"
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case invalidResponse
    case forbidden(detail: String)
    case rateLimited(retryAfterSeconds: Int)
    case httpError(statusCode: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .invalidResponse:
            return "Invalid response from server."
        case .forbidden(let detail):
            return "Access denied: \(detail)"
        case .rateLimited(let seconds):
            return "Rate limited. Try again in \(seconds) seconds."
        case .httpError(let code, let detail):
            return "HTTP \(code): \(detail)"
        }
    }
}
