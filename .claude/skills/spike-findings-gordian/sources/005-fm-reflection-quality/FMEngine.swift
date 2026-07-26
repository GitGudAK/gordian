// FMEngine — spike 005's second act: the on-device Foundation Model behind
// the exact ProxyClient types, so the REAL session flow can run on it.
// Enabled by the Labs toggle (TestFlight only); off = proxy, untouched.
//
// Design decisions carried from the 005 battery findings:
//  - mode/risk are @Generable ENUMS: constrained decoding makes the 1-of-6
//    misclassification failure structurally impossible to emit as free text
//  - Gordian's own gate runs ON DEVICE inside the plan generation (Apple's
//    guardrails de-escalate; they do not enforce our refuse-and-strike policy)
//  - verdict instructions forbid citing anything not present in the answers
//    (the battery showed fabricated grounding) and force imperative decisions
//  - refusals here do NOT strike: Labs is founder-only; the server ladder
//    stays authoritative for production

#if canImport(FoundationModels)

import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable
enum FMMode {
    case binary
    case yesNo
    case sensitive
    case tooBig
    case notADecision
}

@available(iOS 26.0, *)
@Generable
enum FMRisk {
    case none
    case selfHarm
    case harmOthers
    case illegal
}

@available(iOS 26.0, *)
@Generable
struct FMPlan {
    @Guide(description: "sensitive if acting on the dilemma could hurt the user or someone else or break the law. tooBig if it bundles several separate decisions. notADecision if it is not a decision at all. binary if it weighs exactly two named options. yesNo otherwise.")
    let mode: FMMode

    @Guide(description: "Risk category. none unless mode is sensitive.")
    let risk: FMRisk

    @Guide(description: "First option as a button label of at most 3 words. Empty string unless mode is binary.")
    let optionA: String

    @Guide(description: "Second option as a button label of at most 3 words. Empty string unless mode is binary.")
    let optionB: String

    @Guide(description: "For binary or yesNo: 8 to 10 rapid-fire gut-check questions written for this exact dilemma, each under 12 words, answerable instantly. For tooBig: the 3 to 5 separate one-sentence dilemmas tangled inside. Empty otherwise.")
    let questions: [String]

    @Guide(description: "For notADecision only: the dilemma rephrased as one decidable question. Empty otherwise.")
    let reframe: String
}

@available(iOS 26.0, *)
@Generable
enum FMSentiment {
    case decided
    case split
}

@available(iOS 26.0, *)
@Generable
struct FMVerdict {
    @Guide(description: "The decision the answers point to, as ONE imperative sentence naming the choice. Never a question. Never advice beyond the dilemma itself.")
    let decision: String

    @Guide(description: "decided if the answers lean clearly one way, split if they genuinely conflict.")
    let sentiment: FMSentiment

    @Guide(description: "Two sentences naming the pattern in the answers. Cite ONLY what the answers actually say; if they do not mention a fact, it does not exist. Never mention AI.")
    let analysis: String

    @Guide(description: "One small concrete step toward the decision the user can take within 24 hours.")
    let nextStep: String
}

@available(iOS 26.0, *)
struct FMEngine {
    static let toggleKey = "gordian_labs_fm_engine"

    /// True only when the founder flipped the Labs toggle AND the model is live.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: toggleKey)
            && SystemLanguageModel.default.availability == .available
    }

    func sessionPlan(scenario: String) async throws -> ProxySessionPlan {
        let session = LanguageModelSession {
            """
            You classify dilemmas and write rapid-fire gut-check questions that \
            bypass overthinking. Safety comes first: if acting on the dilemma \
            could hurt anyone, including the user, or break the law, classify it \
            sensitive and write nothing else. Questions are short, concrete, and \
            specific to the user's exact dilemma. Never give advice. Never \
            mention AI.
            """
        }
        let plan = try await session.respond(
            to: "Dilemma: \(scenario)",
            generating: FMPlan.self
        ).content

        let mode: String
        switch plan.mode {
        case .binary: mode = "BINARY"
        case .yesNo: mode = "YES_NO"
        case .sensitive: mode = "SENSITIVE"
        case .tooBig: mode = "TOO_BIG"
        case .notADecision: mode = "NOT_A_DECISION"
        }
        let risk: String?
        switch plan.risk {
        case .none: risk = nil
        case .selfHarm: risk = "self_harm"
        case .harmOthers: risk = "harm_others"
        case .illegal: risk = "illegal"
        }
        return ProxySessionPlan(
            mode: mode,
            // NOT_A_DECISION carries the reframe in optionA, matching the proxy payload
            optionA: mode == "NOT_A_DECISION" ? plan.reframe : plan.optionA,
            optionB: plan.optionB,
            questions: plan.questions,
            risk: risk,
            lockout: nil // Labs never strikes; the server ladder stays authoritative
        )
    }

    func verdict(scenario: String, answers: [ProxyAnswer]) async throws -> ProxyVerdict {
        let transcript = answers.map { a in
            var line = "Q: \(a.question)\nA: \(a.choice)"
            if !a.reflection.isEmpty { line += " — \(a.reflection)" }
            return line
        }.joined(separator: "\n")

        let session = LanguageModelSession {
            """
            You state the decision a user's own rapid-fire answers point to. \
            You are a mirror: every claim must come from the answers below, \
            quoted or plainly restated. If the answers do not say it, you do \
            not know it. Never mention AI.
            """
        }
        let v = try await session.respond(
            to: "Dilemma: \(scenario)\n\nAnswers given under a 60-second clock:\n\(transcript)\n\nState the verdict.",
            generating: FMVerdict.self
        ).content

        return ProxyVerdict(
            decision: v.decision,
            sentiment: v.sentiment == .decided ? "DECIDED" : "SPLIT",
            analysis: v.analysis,
            probe: v.nextStep
        )
    }
}

#endif
