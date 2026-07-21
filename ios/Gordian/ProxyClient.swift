// Gordian proxy client — the app ships with no keys and no accounts.
// AI operations call the operator's proxy (Phase 1, Cloudflare Worker), which
// holds the model key, owns the prompts, and enforces rate/spend limits.
// Any failure throws; callers fall back to the offline question bank / tally
// verdict, so a session never dead-ends.

import Foundation

struct ProxySessionPlan: Decodable {
    let mode: String
    let optionA: String
    let optionB: String
    let questions: [String]
}

struct ProxyVerdict: Decodable {
    let decision: String
    let sentiment: String
    let analysis: String
    let probe: String
}

struct ProxyAnswer: Encodable {
    let question: String
    let choice: String
    let reflection: String
}

enum ProxyError: Error {
    /// code is the proxy's machine-readable error code ("rate_limited",
    /// "spend_cap", "upstream_error", ... — "weekly_meter_exhausted" arrives
    /// with the freemium meter). All of them currently mean "use the fallback".
    case api(code: String, message: String)
    case badPayload
}

struct ProxyClient {
    static let baseURL = URL(string: "https://gordian-proxy.gordian-app.workers.dev")!

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 60   // thinking model: ~7s typical, headroom for spikes
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    // Stable anonymous install id. Opaque to the server (it only ever logs a
    // hash); powers per-device rate limits and the weekly session meter.
    static var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "gordian_device_id") { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: "gordian_device_id")
        return id
    }

    func sessionPlan(scenario: String) async throws -> ProxySessionPlan {
        struct Body: Encodable { let scenario: String }
        return try await post("/v1/session-plan", body: Body(scenario: scenario))
    }

    func verdict(scenario: String, answers: [ProxyAnswer]) async throws -> ProxyVerdict {
        struct Body: Encodable {
            let scenario: String
            let answers: [ProxyAnswer]
        }
        return try await post("/v1/verdict", body: Body(scenario: scenario, answers: answers))
    }

    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String?
        }
        let error: Detail
    }

    private func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.deviceID, forHTTPHeaderField: "X-Device-ID")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProxyError.badPayload }
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw ProxyError.api(code: envelope.error.code, message: envelope.error.message ?? "")
            }
            throw ProxyError.api(code: "http_\(http.statusCode)", message: "")
        }
        guard let value = try? JSONDecoder().decode(T.self, from: data) else {
            throw ProxyError.badPayload
        }
        return value
    }
}
