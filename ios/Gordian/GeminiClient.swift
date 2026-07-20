// Gemini generateContent client — port of api/GeminiService.kt with the spike-002 hardening:
//  - responseSchema on every structured call (plain JSON mode is ~60% reliable on this model)
//  - all response parts concatenated (never parts[0] alone)
//  - bracket-repair fallback for truncated arrays

import Foundation

struct GeminiPart: Codable {
    let text: String?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiSchema: Codable {
    let type: String
    let items: [String: String]?
    let properties: [String: [String: String]]?
    let required: [String]?

    static let stringArray = GeminiSchema(type: "ARRAY", items: ["type": "STRING"], properties: nil, required: nil)

    static func object(fields: [String]) -> GeminiSchema {
        GeminiSchema(
            type: "OBJECT",
            items: nil,
            properties: Dictionary(uniqueKeysWithValues: fields.map { ($0, ["type": "STRING"]) }),
            required: fields
        )
    }
}

struct GeminiGenerationConfig: Codable {
    let temperature: Float?
    let responseMimeType: String?
    let responseSchema: GeminiSchema?
}

struct GenerateContentRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
    let systemInstruction: GeminiContent?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
    let finishReason: String?
}

struct GenerateContentResponse: Codable {
    let candidates: [GeminiCandidate]?
}

struct GeminiErrorEnvelope: Codable {
    struct Detail: Codable {
        let code: Int?
        let message: String?
        let status: String?
    }
    let error: Detail?
}

enum GeminiError: Error {
    case http(Int, String)
    case emptyResponse
    case badPayload
}

struct GeminiClient {
    let apiKey: String
    var model: String = "gemini-3.5-flash"

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    func generateText(system: String, user: String, temperature: Float, schema: GeminiSchema?) async throws -> String {
        var comps = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GenerateContentRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: user)])],
            generationConfig: GeminiGenerationConfig(temperature: temperature, responseMimeType: "application/json", responseSchema: schema),
            systemInstruction: GeminiContent(parts: [GeminiPart(text: system)])
        ))

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GeminiError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data)
            throw GeminiError.http(http.statusCode, envelope?.error?.message ?? "unknown error")
        }
        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let text = (decoded.candidates?.first?.content?.parts ?? []).compactMap(\.text).joined()
        guard !text.isEmpty else { throw GeminiError.emptyResponse }
        return text
    }

    // Port of the Android markdown-fence cleanup (MainViewModel cleanJson)
    static func cleanJSONText(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        if s.hasPrefix("```") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func generateStringArray(system: String, user: String, temperature: Float) async throws -> [String] {
        let text = try await generateText(system: system, user: user, temperature: temperature, schema: .stringArray)
        let clean = Self.cleanJSONText(text)
        if let array = try? JSONDecoder().decode([String].self, from: Data(clean.utf8)) {
            return array
        }
        // Bracket repair: the thinking model occasionally drops the closing "]"
        var repaired = clean
        if repaired.hasSuffix(",") { repaired = String(repaired.dropLast()) }
        if repaired.hasPrefix("["), !repaired.hasSuffix("]") { repaired += "]" }
        if let array = try? JSONDecoder().decode([String].self, from: Data(repaired.utf8)) {
            return array
        }
        throw GeminiError.badPayload
    }

    func generateObject<T: Decodable>(_ type: T.Type, fields: [String], system: String, user: String, temperature: Float) async throws -> T {
        let text = try await generateText(system: system, user: user, temperature: temperature, schema: .object(fields: fields))
        let clean = Self.cleanJSONText(text)
        guard let value = try? JSONDecoder().decode(T.self, from: Data(clean.utf8)) else {
            throw GeminiError.badPayload
        }
        return value
    }
}
