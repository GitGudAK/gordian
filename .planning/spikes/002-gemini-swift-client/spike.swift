// Spike 002: Gemini from Swift URLSession + Codable (Swift 5.4 compatible — no async/await)
// Ports the exact REST contract used by the Android app (GeminiService.kt).
//
// Usage:
//   swiftc -o spike002 spike.swift
//   ./spike002 fixtures                 # offline: validate Codable decoding against fixtures
//   GEMINI_API_KEY=... ./spike002 questions   # live: generate 12 bypass questions
//   GEMINI_API_KEY=... ./spike002 verdict     # live: synthesize a Gordian Verdict
//   ./spike002 errorpath                # live endpoint, bad key: validate error handling
//   GEMINI_API_KEY=... ./spike002 all
//
// Optional: GEMINI_MODEL to override the model (default matches Android: gemini-3.5-flash)

import Foundation

// MARK: - Forensic log layer

struct LogEvent: Codable {
    let ts: String
    let category: String
    let message: String
    let meta: [String: String]
}

final class ForensicLog {
    private var events: [LogEvent] = []
    private let started = Date()
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func log(_ category: String, _ message: String, meta: [String: String] = [:]) {
        let e = LogEvent(ts: iso.string(from: Date()), category: category, message: message, meta: meta)
        events.append(e)
        print("[\(category)] \(message)")
    }

    func export(to path: String) {
        let summary: [String: String] = [
            "events": String(events.count),
            "durationSeconds": String(format: "%.2f", Date().timeIntervalSince(started)),
            "errors": String(events.filter { $0.category == "ERROR" }.count)
        ]
        var byCategory: [String: Int] = [:]
        for e in events { byCategory[e.category, default: 0] += 1 }
        let doc: [String: AnyEncodable] = [
            "summary": AnyEncodable(summary),
            "eventCountsByCategory": AnyEncodable(byCategory.mapValues { String($0) }),
            "events": AnyEncodable(events)
        ]
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(doc) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("[LOG] forensic log exported to \(path) (\(events.count) events)")
        }
    }
}

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { self.encodeFunc = value.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

let flog = ForensicLog()

// MARK: - DTOs (1:1 port of GeminiService.kt Moshi models)

struct GPart: Codable { let text: String? }
struct GContent: Codable { let parts: [GPart] }
struct GSchema: Codable {
    let type: String
    let items: [String: String]?
}
struct GGenerationConfig: Codable {
    let temperature: Float?
    let responseMimeType: String?
    let responseSchema: GSchema?
}
struct GenerateContentRequest: Codable {
    let contents: [GContent]
    let generationConfig: GGenerationConfig?
    let systemInstruction: GContent?
}
struct GCandidate: Codable { let content: GContent?; let finishReason: String? }
struct GenerateContentResponse: Codable { let candidates: [GCandidate]? }

// Google error envelope for non-2xx responses
struct GErrorDetail: Codable { let code: Int?; let message: String?; let status: String? }
struct GErrorEnvelope: Codable { let error: GErrorDetail? }

// MARK: - Client

enum GeminiError: Error, CustomStringConvertible {
    case transport(String)
    case http(Int, String)
    case emptyResponse
    case badJSON(String)
    var description: String {
        switch self {
        case .transport(let m): return "transport: \(m)"
        case .http(let c, let m): return "http \(c): \(m)"
        case .emptyResponse: return "empty response (no candidates/parts/text)"
        case .badJSON(let m): return "bad JSON payload: \(m)"
        }
    }
}

final class GeminiClient {
    let apiKey: String
    let model: String
    let session: URLSession

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    // Synchronous wrapper (Swift 5.4: no async/await available)
    func generateContent(_ request: GenerateContentRequest) -> Result<String, GeminiError> {
        var comps = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONEncoder().encode(request)
        } catch {
            return .failure(.badJSON("encode failed: \(error)"))
        }

        var result: Result<String, GeminiError> = .failure(.transport("no callback"))
        let sem = DispatchSemaphore(value: 0)
        let start = Date()
        let task = session.dataTask(with: req) { data, response, error in
            defer { sem.signal() }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            if let error = error {
                result = .failure(.transport(error.localizedDescription))
                return
            }
            guard let http = response as? HTTPURLResponse, let data = data else {
                result = .failure(.transport("no response/data"))
                return
            }
            flog.log("HTTP", "status \(http.statusCode) in \(ms)ms", meta: ["bytes": String(data.count)])
            guard (200..<300).contains(http.statusCode) else {
                let envelope = try? JSONDecoder().decode(GErrorEnvelope.self, from: data)
                let msg = envelope?.error?.message ?? String(data: data.prefix(300), encoding: .utf8) ?? "?"
                result = .failure(.http(http.statusCode, msg))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
                try? data.write(to: URL(fileURLWithPath: dirOf() + "/debug-last-raw.json"))
                let fr = decoded.candidates?.first?.finishReason ?? "nil"
                flog.log("HTTP", "finishReason=\(fr)")
                if fr != "STOP" {
                    flog.log("WARN", "response did not complete normally")
                }
                let parts = decoded.candidates?.first?.content?.parts ?? []
                if parts.count > 1 {
                    flog.log("WARN", "response contains \(parts.count) parts — concatenating (parts[0]-only readers truncate!)")
                }
                let text = parts.compactMap { $0.text }.joined()
                guard !text.isEmpty else {
                    result = .failure(.emptyResponse)
                    return
                }
                result = .success(text)
            } catch {
                result = .failure(.badJSON("decode failed: \(error)"))
            }
        }
        task.resume()
        sem.wait()
        return result
    }
}

func dirOf() -> String { (CommandLine.arguments[0] as NSString).deletingLastPathComponent }

// Port of the Android markdown-fence cleanup (MainViewModel cleanJson logic)
func cleanJSONText(_ raw: String) -> String {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
    if s.hasPrefix("```") { s = String(s.dropFirst(3)) }
    if s.hasSuffix("```") { s = String(s.dropLast(3)) }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Payload builders (1:1 port of MainViewModel prompts)

func bypassQuestionsRequest(scenario: String, qaPairs: String) -> GenerateContentRequest {
    let system = "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass. "
        + "The user has a dilemma: '\(scenario)'.\n"
        + "Insights gathered from clarification dialogue:\n\(qaPairs)\n"
        + "Generate exactly 12 rapid-fire, high-intensity bypass questions (maximum 10 words each, answers should be Yes or No) "
        + "designed to bypass the analytical brain, force an immediate gut response, and highlight subconscious desires or core fears.\n"
        + "Format your response as a JSON array of strings: [\"Question 1?\", \"Question 2?\", ..., \"Question 12?\"] "
        + "Output ONLY the JSON array. No markdown, no formatting, no code blocks."
    return GenerateContentRequest(
        contents: [GContent(parts: [GPart(text: "Generate exactly 12 psychological bypass questions based on the dilemma and dialogue.")])],
        // responseSchema: constrained decoding — the fix for the thinking model's
        // intermittent missing-closing-bracket output (see Investigation Trail #8)
        generationConfig: GGenerationConfig(
            temperature: 0.8,
            responseMimeType: "application/json",
            responseSchema: GSchema(type: "ARRAY", items: ["type": "STRING"])
        ),
        systemInstruction: GContent(parts: [GPart(text: system)])
    )
}

func verdictRequest(scenario: String, clarifying: String, rapidFire: String) -> GenerateContentRequest {
    let system = "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass and final decisional resolution. "
        + "The user has this dilemma: '\(scenario)'.\n"
        + "Dialogue where we clarified their dilemma:\n\(clarifying)\n"
        + "During a high-pressure 60-second rapid-fire session, they gave the following reactions:\n\(rapidFire)\n\n"
        + "Analyze their answers deeply. Look for inconsistencies, emotional triggers, subconscious patterns, and where their gut stance truly lies versus their rationalizations. "
        + "Synthesize this into a final definitive diagnostic breakthrough (The Gordian Verdict). "
        + "Your response MUST be in JSON format with exactly three string fields:\n"
        + "1. \"sentiment\": A single short status or affective state.\n"
        + "2. \"analysis\": A powerful, deep, compassionate 3-4 sentence psychological breakdown.\n"
        + "3. \"probe\": A final provoking, empowering query or action step.\n"
        + "Output ONLY the JSON object. Do not include markdown or formatting."
    return GenerateContentRequest(
        contents: [GContent(parts: [GPart(text: "Synthesize a final Gordian Verdict and return JSON.")])],
        generationConfig: GGenerationConfig(temperature: 0.8, responseMimeType: "application/json", responseSchema: nil),
        systemInstruction: GContent(parts: [GPart(text: system)])
    )
}

struct Verdict: Codable { let sentiment: String; let analysis: String; let probe: String }

// Defensive repair for truncated JSON arrays (missing closing bracket) — belt to
// responseSchema's suspenders. Returns nil if the payload can't be salvaged.
func repairJSONArray(_ clean: String) -> [String]? {
    guard clean.hasPrefix("[") else { return nil }
    var s = clean.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasSuffix(",") { s = String(s.dropLast()) }
    if !s.hasSuffix("]") { s += "]" }
    return try? JSONDecoder().decode([String].self, from: Data(s.utf8))
}

// MARK: - Tests

func testFixtures() -> Bool {
    flog.log("TEST", "fixtures: decoding captured response shapes offline")
    let dir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
    var ok = true
    for name in ["response-questions.json", "response-verdict.json", "response-error.json"] {
        let path = dir + "/fixtures/" + name
        guard let data = FileManager.default.contents(atPath: path) else {
            flog.log("ERROR", "fixture missing: \(path)"); ok = false; continue
        }
        if name == "response-error.json" {
            if let env = try? JSONDecoder().decode(GErrorEnvelope.self, from: data), let msg = env.error?.message {
                flog.log("PASS", "error envelope decodes: \(msg)")
            } else { flog.log("ERROR", "error envelope failed to decode"); ok = false }
            continue
        }
        guard let decoded = try? JSONDecoder().decode(GenerateContentResponse.self, from: data),
              let text = decoded.candidates?.first?.content?.parts.first?.text else {
            flog.log("ERROR", "\(name): DTO decode failed"); ok = false; continue
        }
        let clean = cleanJSONText(text)
        if name == "response-questions.json" {
            if let qs = try? JSONDecoder().decode([String].self, from: Data(clean.utf8)) {
                flog.log("PASS", "questions fixture → \(qs.count) questions decoded", meta: ["first": qs.first ?? ""])
                if qs.count != 12 { flog.log("WARN", "expected 12, got \(qs.count)") }
            } else { flog.log("ERROR", "questions payload not a JSON string array"); ok = false }
        } else {
            if let v = try? JSONDecoder().decode(Verdict.self, from: Data(clean.utf8)) {
                flog.log("PASS", "verdict fixture → sentiment=\(v.sentiment)")
            } else { flog.log("ERROR", "verdict payload not a {sentiment,analysis,probe} object"); ok = false }
        }
    }
    return ok
}

func testLiveQuestions(client: GeminiClient) -> Bool {
    flog.log("TEST", "live: 12 bypass questions (model=\(client.model))")
    let req = bypassQuestionsRequest(
        scenario: "I have a job offer at a startup but my current corporate job is stable",
        qaPairs: "Q: What is the single greatest risk holding you back? -> A: Losing my savings runway\n"
    )
    switch client.generateContent(req) {
    case .failure(let e):
        flog.log("ERROR", "questions call failed: \(e)")
        return false
    case .success(let text):
        let clean = cleanJSONText(text)
        var decoded = try? JSONDecoder().decode([String].self, from: Data(clean.utf8))
        if decoded == nil {
            if let repaired = repairJSONArray(clean) {
                flog.log("REPAIR", "payload was truncated (missing ]) — bracket repair recovered \(repaired.count) questions")
                decoded = repaired
            }
        }
        guard let qs = decoded else {
            flog.log("ERROR", "payload was not a JSON string array (\(clean.count) chars). Last 80: ...\(String(clean.suffix(80)))")
            try? Data(clean.utf8).write(to: URL(fileURLWithPath: dirOf() + "/debug-questions-payload.txt"))
            return false
        }
        flog.log("PASS", "decoded \(qs.count) questions")
        if qs.count != 12 { flog.log("WARN", "prompt asked for exactly 12, got \(qs.count) — real build should tolerate 5-15") }
        print("\n  ── Bypass questions (as the iOS app would show them) ──")
        for (i, q) in qs.enumerated() { print("  \(String(format: "%2d", i + 1)). \(q)") }
        print("")
        let tooLong = qs.filter { $0.split(separator: " ").count > 12 }
        if !tooLong.isEmpty { flog.log("WARN", "\(tooLong.count) questions exceed the 10-word prompt constraint") }
        return true
    }
}

func testLiveVerdict(client: GeminiClient) -> Bool {
    flog.log("TEST", "live: Gordian Verdict synthesis")
    let req = verdictRequest(
        scenario: "I have a job offer at a startup but my current corporate job is stable",
        clarifying: "Q: What is the single greatest risk? -> A: Losing my savings runway\n",
        rapidFire: "1. Q: Are you choosing out of ambition or fear? -> Response: YES (Reflection: mostly fear of stagnation)\n"
            + "2. Q: Would your 80-year-old self regret staying? -> Response: YES\n"
            + "3. Q: Is stability actually growth? -> Response: NO\n"
    )
    switch client.generateContent(req) {
    case .failure(let e):
        flog.log("ERROR", "verdict call failed: \(e)")
        return false
    case .success(let text):
        let clean = cleanJSONText(text)
        guard let v = try? JSONDecoder().decode(Verdict.self, from: Data(clean.utf8)) else {
            flog.log("ERROR", "payload was not a {sentiment,analysis,probe} object. First 200 chars: \(String(clean.prefix(200)))")
            return false
        }
        flog.log("PASS", "verdict decoded")
        print("\n  ── Gordian Verdict (as the iOS app would show it) ──")
        print("  SENTIMENT: \(v.sentiment.uppercased())")
        print("  ANALYSIS:  \(v.analysis)")
        print("  PROBE:     \(v.probe)\n")
        return true
    }
}

func testErrorPath(model: String) -> Bool {
    flog.log("TEST", "live: invalid key → structured error envelope")
    let bad = GeminiClient(apiKey: "INVALID_KEY_SPIKE_002", model: model)
    let req = bypassQuestionsRequest(scenario: "test", qaPairs: "")
    switch bad.generateContent(req) {
    case .success:
        flog.log("ERROR", "expected failure with invalid key but call succeeded")
        return false
    case .failure(let e):
        switch e {
        case .http(let code, let msg):
            flog.log("PASS", "got structured HTTP error \(code): \(String(msg.prefix(120)))")
            return true
        case .transport(let m):
            flog.log("WARN", "transport-level failure (offline/sandboxed?): \(m)")
            return false
        default:
            flog.log("ERROR", "unexpected error shape: \(e)")
            return false
        }
    }
}

// MARK: - Main

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "all"
let model = ProcessInfo.processInfo.environment["GEMINI_MODEL"] ?? "gemini-3.5-flash"
let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""

flog.log("START", "spike002 mode=\(mode) model=\(model) swift=5.4-compat")

var allOK = true
var ranLive = false

if mode == "fixtures" || mode == "all" {
    allOK = testFixtures() && allOK
}
if mode == "errorpath" || mode == "all" {
    allOK = testErrorPath(model: model) && allOK
    ranLive = true
}
if mode == "questions" || mode == "verdict" || mode == "all" {
    if key.isEmpty {
        flog.log(mode == "all" ? "WARN" : "ERROR", "GEMINI_API_KEY not set — skipping live generation tests")
        if mode != "all" { allOK = false }
    } else {
        let client = GeminiClient(apiKey: key, model: model)
        if mode == "questions" || mode == "all" { allOK = testLiveQuestions(client: client) && allOK }
        if mode == "verdict" || mode == "all" { allOK = testLiveVerdict(client: client) && allOK }
        ranLive = true
    }
}

let dir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
flog.export(to: dir + "/spike002-log.json")
print(allOK ? "\n✅ SPIKE 002: all executed tests passed\(ranLive ? "" : " (offline only)")" : "\n❌ SPIKE 002: failures — see spike002-log.json")
exit(allOK ? 0 : 1)
