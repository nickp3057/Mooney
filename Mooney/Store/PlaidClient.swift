import Foundation

enum PlaidClientError: LocalizedError {
    case noBackendURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .noBackendURL: return "No backend URL is set in Settings."
        case .invalidResponse: return "The backend returned an unexpected response."
        case .server(let message): return message
        }
    }
}

// Thin wrapper around the 4 endpoints exposed by Backend/server.js. The
// backend is the only thing that ever holds a Plaid secret or access_token —
// this client just relays requests to it, same separation of concerns the
// app already uses for the PIN (AppLockManager, kept out of AppState).
struct PlaidClient {
    static let backendURLDefaultsKey = "mooney_plaid_backend_url"
    static let isConnectedDefaultsKey = "mooney_plaid_connected"

    static var backendURL: String? {
        get { UserDefaults.standard.string(forKey: backendURLDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: backendURLDefaultsKey) }
    }

    // Local-only convenience flag — the backend is the actual source of
    // truth for whether an Item is connected (a 404 from /balance means
    // "not connected"), but mirroring it here lets the Settings screen show
    // Connect/Disconnect without a round trip on every render.
    static var isConnected: Bool {
        get { UserDefaults.standard.bool(forKey: isConnectedDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: isConnectedDefaultsKey) }
    }

    private func baseURL() throws -> URL {
        guard let raw = Self.backendURL, !raw.isEmpty, let url = URL(string: raw) else {
            throw PlaidClientError.noBackendURL
        }
        return url
    }

    private func send(_ path: String, method: String, body: [String: Any]? = nil) async throws -> Data {
        let url = try baseURL().appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlaidClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            struct ErrorBody: Decodable { let error: String }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw PlaidClientError.server(message ?? "Request failed with status \(http.statusCode)")
        }
        return data
    }

    func createLinkToken() async throws -> String {
        struct Response: Decodable { let link_token: String }
        let data = try await send("link_token", method: "POST")
        return try JSONDecoder().decode(Response.self, from: data).link_token
    }

    func exchangePublicToken(_ publicToken: String, accountId: String) async throws {
        _ = try await send("exchange_public_token", method: "POST", body: [
            "public_token": publicToken,
            "account_id": accountId
        ])
    }

    func fetchBalance() async throws -> PlaidBalance {
        struct Response: Decodable {
            let name: String
            let current: Double?
            let available: Double?
            let isoCurrencyCode: String?
            let asOf: String
        }
        let data = try await send("balance", method: "GET")
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return PlaidBalance(
            accountName: decoded.name,
            current: decoded.current,
            available: decoded.available,
            isoCurrencyCode: decoded.isoCurrencyCode,
            asOf: ISO8601DateFormatter().date(from: decoded.asOf) ?? Date()
        )
    }

    func disconnect() async throws {
        _ = try await send("disconnect", method: "POST")
    }
}
