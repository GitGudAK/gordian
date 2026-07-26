// Spike 005: fm-reflection-quality
//
// Validates: given a real dilemma, when the on-device Foundation Model
// generates a session plan and a verdict via guided generation, then output
// quality / latency / refusal-rate is acceptable vs the Gemini proxy.
//
// The battery mirrors the proxy's two premium calls (session plan, verdict)
// with @Generable structs shaped like the production payloads. Six canned
// dilemmas cover binary / yes-no / open / tangled / borderline-sensitive —
// the borderline ones probe Apple's guardrails, which refuse content the
// Gemini gate currently allows through as ordinary dilemmas.

#if canImport(FoundationModels)

import SwiftUI
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct LabsSessionPlan {
    @Guide(description: "BINARY if the dilemma weighs exactly two options, YES_NO if it is a yes-or-no question, OPEN otherwise")
    let mode: String
    @Guide(description: "First option as a button label of at most 3 words. Empty string unless mode is BINARY.")
    let optionA: String
    @Guide(description: "Second option as a button label of at most 3 words. Empty string unless mode is BINARY.")
    let optionB: String
    @Guide(description: "Exactly 8 rapid-fire gut-check questions written for this specific dilemma, each under 12 words, answerable instantly with a gut yes/no or option choice")
    let questions: [String]
}

@available(iOS 26.0, *)
@Generable
struct LabsVerdict {
    @Guide(description: "The decision the answers point to, stated in one plain imperative sentence")
    let decision: String
    @Guide(description: "Two sentences explaining the pattern in the user's own answers that led here. Never mention AI or models.")
    let why: String
    @Guide(description: "One small concrete step the user can take within 24 hours")
    let nextStep: String
}

@available(iOS 26.0, *)
struct LabsFMView: View {
    @State private var log = LabsLog()
    @State private var running = false
    @State private var statusLine = "Idle"
    @State private var results: [String] = []
    @State private var customDilemma = ""

    private static let battery: [(name: String, dilemma: String)] = [
        ("binary-job", "Should I take the new job at the startup or stay in my stable role at the bank?"),
        ("yesno-move", "Should I move back home to be closer to family?"),
        ("open-career", "I feel stuck in my career and don't know what to change."),
        ("tangled", "Should I quit my job, move to Lisbon, and start a design studio with my brother even though we argue a lot?"),
        ("edge-confront", "Should I confront my neighbor about the noise at night?"),
        ("edge-risky", "Should I put my savings into day trading full time?")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                availabilityCard

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "BATTERY (6 DILEMMAS)", tracking: 1)
                    Text("Runs plan + verdict for each dilemma sequentially and logs latency, output, and refusals.")
                        .font(.footnote).foregroundColor(.textMuted)
                    Button(running ? "Running… \(statusLine)" : "Run full battery") {
                        Task { await runBattery() }
                    }
                    .disabled(running)
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .gordianCard(cornerRadius: 16)

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "SINGLE DILEMMA", tracking: 1)
                    TextField("Type a dilemma to test", text: $customDilemma, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Run this one") {
                        Task { await runOne(name: "custom", dilemma: customDilemma) }
                    }
                    .disabled(running || customDilemma.isEmpty)
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .gordianCard(cornerRadius: 16)

                ForEach(results.indices, id: \.self) { i in
                    Text(results[i])
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.textLight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .gordianCard(cornerRadius: 12)
                }

                if let url = log.exportURL(name: "spike-005-fm-reflection") {
                    ShareLink(item: url) {
                        Label("Export forensic log (\(log.events.count) events)", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .padding(20)
        }
        .background(Color.darkBackground)
        .navigationTitle("005 · Foundation Model")
    }

    private var availabilityCard: some View {
        let model = SystemLanguageModel.default
        let text: String
        switch model.availability {
        case .available:
            text = "Model AVAILABLE on this device"
        case .unavailable(let reason):
            text = "UNAVAILABLE: \(String(describing: reason))"
        }
        return Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(text.hasPrefix("Model") ? .goldPrimary : .redAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .gordianCard(cornerRadius: 16)
    }

    private func runBattery() async {
        running = true
        log.log("battery", "started", data: ["count": "\(Self.battery.count)"])
        for item in Self.battery {
            await runOne(name: item.name, dilemma: item.dilemma)
        }
        log.log("battery", "finished")
        running = false
        statusLine = "Done"
    }

    private func runOne(name: String, dilemma: String) async {
        running = true
        statusLine = name
        let clock = ContinuousClock()

        // Fresh session per dilemma: mirrors production (no cross-dilemma
        // context) and sidesteps the small on-device context window.
        let session = LanguageModelSession {
            """
            You write rapid-fire gut-check questions that bypass overthinking. \
            Questions are short, concrete, and specific to the user's dilemma. \
            Never give advice. Never mention AI.
            """
        }

        do {
            let planStart = clock.now
            let plan = try await session.respond(
                to: "Dilemma: \(dilemma)",
                generating: LabsSessionPlan.self
            )
            let planMs = (clock.now - planStart).ms
            log.log("plan", name, data: [
                "latencyMs": "\(planMs)",
                "mode": plan.content.mode,
                "optionA": plan.content.optionA,
                "optionB": plan.content.optionB,
                "questionCount": "\(plan.content.questions.count)",
                "questions": plan.content.questions.joined(separator: " | ")
            ])

            // Simulated answers: alternate leans, as a real session would produce
            let answers = plan.content.questions.enumerated()
                .map { i, q in "\(q) -> \(i % 3 == 0 ? "hesitant no" : "instant yes")" }
                .joined(separator: "\n")

            let verdictStart = clock.now
            let verdict = try await session.respond(
                to: "The user answered under a 60-second clock:\n\(answers)\nState the verdict.",
                generating: LabsVerdict.self
            )
            let verdictMs = (clock.now - verdictStart).ms
            log.log("verdict", name, data: [
                "latencyMs": "\(verdictMs)",
                "decision": verdict.content.decision,
                "why": verdict.content.why,
                "nextStep": verdict.content.nextStep
            ])
            results.append("[\(name)] plan \(planMs)ms · verdict \(verdictMs)ms\nQ1: \(plan.content.questions.first ?? "-")\nDecision: \(verdict.content.decision)")
        } catch {
            // Guardrail refusals and context overflows land here — the error
            // description distinguishes them in the exported log.
            log.log("error", name, data: ["error": String(describing: error)])
            results.append("[\(name)] ERROR: \(String(describing: error))")
        }
        running = false
    }
}

@available(iOS 26.0, *)
private extension Duration {
    var ms: Int { Int(Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15) }
}

#endif
