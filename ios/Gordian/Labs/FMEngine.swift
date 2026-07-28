// FMEngine — the on-device Foundation Model behind the exact ProxyClient
// types, so the REAL session flow can run on it. Enabled by the Labs toggle
// (TestFlight only); off = proxy, untouched.
//
// Structure mirrors the production proxy's two-tier design 1:1 — lessons
// bought live on device:
//  - TIER 1 classifies (risk, mode, options) with NOTHING else to think
//    about. A merged classify-and-write-questions generation put its
//    attention on questions and let a vandalism dilemma through the gate.
//  - TIER 2 writes questions FOR an already-decided mode, receiving the
//    option labels as input. Without that, binary sessions got yes/no and
//    "how much" questions the two option buttons cannot answer.
//  - Enums everywhere classification happens: constrained decoding makes
//    misclassification structurally impossible to emit.
//  - NO negative examples in prompts: the 3B model reproduced the "bad"
//    example verbatim in a real session. Show it only what good looks like.
//  - Verdict instructions forbid citing anything not present in the answers
//    (fabricated grounding observed) and force imperative decisions.
//  - Refusals here do NOT strike: Labs is founder-only; the server ladder
//    stays authoritative for the proxy path.

#if canImport(FoundationModels)

import Foundation
import FoundationModels

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
enum FMMode {
    case binary
    case yesNo
    case tooBig
    case notADecision
}

// TIER 1 — classification only. Assessment comes first on purpose: the model
// states what acting on the dilemma involves before it judges (declaration
// order is generation order).
@available(iOS 26.0, *)
@Generable
struct FMGateCheck {
    @Guide(description: "One sentence: what would acting on this dilemma actually involve doing?")
    let assessment: String

    @Guide(description: "harmOthers if acting on it would damage any person or their property (vandalism, revenge, sabotage, violence). selfHarm if it involves hurting oneself. illegal if it would break the law even with no victim. none for ordinary life choices — money, career, relationships, and conversations, even hard or risky ones, are none.")
    let risk: FMRisk

    @Guide(description: "binary if it weighs exactly two named alternatives the user could act on. yesNo if it is a single go/no-go decision the user could act on. tooBig if it bundles several separate decisions. notADecision if there is NO personal choice the user could act on — trivia, questions of fact or general opinion, venting, and statements are all notADecision.")
    let mode: FMMode

    @Guide(description: "For binary: first alternative as a Title Case button label of 1-3 words. Empty otherwise.")
    let optionA: String

    @Guide(description: "For binary: second alternative as a Title Case button label of 1-3 words. Empty otherwise.")
    let optionB: String

    @Guide(description: "For tooBig: the 3 to 5 separate one-sentence dilemmas tangled inside. Empty otherwise.")
    let knots: [String]

    @Guide(description: "For notADecision: the input rephrased as one decidable question. Empty otherwise.")
    let reframe: String
}

// TIER 2 — questions for a known mode, nothing else.
@available(iOS 26.0, *)
@Generable
struct FMQuestions {
    @Guide(description: "8 to 10 rapid-fire gut-check questions, each under 12 words, each naming a concrete detail of this exact dilemma — its people, options, or stakes.")
    let questions: [String]
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
        // TIER 1 — gate + classification, alone (~1s, on-device, free)
        let gateSession = LanguageModelSession {
            """
            You are the gate for a decision app. You judge whether ACTING on \
            the user's dilemma would hurt someone, damage property, or break \
            the law — ordinary hard life choices (money, career, \
            relationships, difficult conversations) pass as none — and you \
            classify what kind of decision it is.
            """
        }
        let gate = try await gateSession.respond(
            to: "Dilemma: \(scenario)",
            generating: FMGateCheck.self
        ).content

        if gate.risk != .none {
            let risk: String
            switch gate.risk {
            case .selfHarm: risk = "self_harm"
            case .harmOthers: risk = "harm_others"
            case .illegal: risk = "illegal"
            case .none: risk = "harm_others" // unreachable
            }
            return ProxySessionPlan(
                mode: "SENSITIVE", optionA: "", optionB: "", questions: [],
                risk: risk,
                lockout: nil // Labs never strikes; the server ladder stays authoritative
            )
        }

        switch gate.mode {
        case .notADecision:
            // The reframe travels in optionA, matching the proxy payload
            return ProxySessionPlan(mode: "NOT_A_DECISION", optionA: gate.reframe,
                                    optionB: "", questions: [], risk: nil, lockout: nil)
        case .tooBig:
            return ProxySessionPlan(mode: "TOO_BIG", optionA: "", optionB: "",
                                    questions: gate.knots, risk: nil, lockout: nil)
        case .binary, .yesNo:
            break
        }

        // TIER 2 — questions for the decided mode. The answer buttons are the
        // interaction contract: every question must be answerable by tapping
        // one of them (ported from the proxy's proven prompt).
        let isBinary = gate.mode == .binary
        let optionA = isBinary ? gate.optionA : "No"
        let optionB = isBinary ? gate.optionB : "Yes"
        let framing = isBinary
            ? """
              The user answers every question by tapping one of two buttons: \
              '\(optionA)' or '\(optionB)'. CRITICAL: every question must be \
              answerable INSTANTLY by tapping one of those buttons. Frame each \
              as a forced choice — like 'Which one would you start tonight?' \
              or 'Which would you regret never trying?' — never yes/no \
              phrasing, never 'how much' phrasing.
              """
            : """
              The user answers every question by tapping 'Yes' or 'No'. \
              CRITICAL: every question must be a direct yes/no question about \
              this exact dilemma — never open-ended, never 'how much' phrasing.
              """
        // Few-shot: a 3B model imitates far better than it follows rules, so
        // it is SHOWN complete dilemma -> questions pairs (drawn from the
        // judged corpus) rather than only told the contract. Positive
        // examples only — a "bad" example in the prompt got reproduced
        // verbatim in a live session.
        let qSession = LanguageModelSession {
            """
            You write rapid-fire gut-check questions that bypass overthinking \
            for a decision app. \(framing) Build every question FROM the \
            user's exact dilemma — name its people, options, and stakes. \
            Never give advice. Never mention AI.

            \(isBinary ? Self.binaryShots : Self.yesNoShots)
            """
        }

        // Best-of-N: generation is ~1.5s on device, so ask three times and
        // keep the best set. Small models are inconsistent rather than
        // uniformly weak — sampling and scoring converts that inconsistency
        // into quality for latency we can afford.
        var best: [String] = []
        var bestScore = -1
        for attempt in 0..<3 {
            let prompt = attempt == 0
                ? "Dilemma: \(scenario)"
                : "Dilemma: \(scenario)\nWrite a different set. Every question must be answered by tapping '\(optionA)' or '\(optionB)', and must name something specific from this dilemma."
            guard let candidate = try? await qSession.respond(
                to: prompt, generating: FMQuestions.self
            ).content.questions.filter({ Self.obeysButtons($0, isBinary: isBinary) })
            else { continue }

            let score = Self.score(candidate, scenario: scenario)
            if score > bestScore { bestScore = score; best = candidate }
            // Ten clean, specific questions is as good as this gets; stop early
            if candidate.count >= 8 && score >= candidate.count * 2 { break }
        }
        let valid = best
        guard valid.count >= 5 else {
            throw ProxyError.api(code: "fm_contract", message: "on-device questions failed the button contract")
        }

        return ProxySessionPlan(
            mode: isBinary ? "BINARY" : "YES_NO",
            optionA: optionA,
            optionB: optionB,
            questions: valid,
            risk: nil,
            lockout: nil
        )
    }

    // MARK: - Few-shot exemplars (from the judged corpus, spike 009)

    static let binaryShots = """
        Example dilemma: "Should I take the product manager offer at the fintech \
        startup or stay senior engineer at my current company?"
        Options: 'Startup PM' or 'Senior Engineer'
        Questions:
        Which version of you does five-years-older you thank?
        Startup dies in a year: which regret stings less?
        Which one would you sign tonight, no counteroffers allowed?
        Which Monday morning feels lighter: roadmaps or pull requests?
        Which loss scares you more: equity upside or seniority?

        Example dilemma: "Should I move in with Maya after eight months or wait \
        until the lease ends next summer?"
        Options: 'Move In Now' or 'Wait For Summer'
        Questions:
        Gut first: whose kitchen are you in next March?
        Is waiting for the lease prudence or a hiding place?
        Which choice would Maya say you actually want?
        If the lease didn't exist, what's your answer?
        Whose toothbrush is already where?
        """

    static let yesNoShots = """
        Example dilemma: "Should I quit my job without another one lined up?"
        Questions:
        Is Sunday night dread now your normal?
        Would three months of runway survive your spending?
        Would you take your own job if offered today?
        Does your body feel lighter saying 'I quit' out loud?
        Is fear of the gap the only thing keeping you?

        Example dilemma: "Should I move back home to be closer to my aging parents?"
        Questions:
        Is this guilt calling, or love calling?
        Would you regret the missed years at their table?
        Would monthly visits quiet the same ache?
        Is your current city home, or just where you live?
        If Dad's health turned tomorrow, where are you standing?
        """

    /// Ranks a candidate question set: contract-clean questions are the floor,
    /// and each one that names a distinctive word from the user's own dilemma
    /// scores double — specificity is what separates a Gordian question from
    /// a survey question.
    static func score(_ questions: [String], scenario: String) -> Int {
        let stop: Set<String> = ["should", "would", "could", "about", "there", "their", "which",
                                 "what", "when", "with", "that", "this", "have", "from", "into",
                                 "your", "yours", "mine", "they", "them", "than", "then", "just",
                                 "keep", "want", "even", "still", "been", "being", "make"]
        let salient = Set(scenario.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stop.contains($0) })
        return questions.reduce(0) { total, q in
            let words = Set(q.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
            return total + (words.isDisjoint(with: salient) ? 1 : 2)
        }
    }

    /// Cheap runtime mirror of the dataset judge: can the answer buttons
    /// answer this question?
    static func obeysButtons(_ question: String, isBinary: Bool) -> Bool {
        let q = question.lowercased()
        // Open-ended interrogatives no button can answer, in either mode
        for banned in ["how many", "how much", "how often", "how important", "what ", "what's", "why ", "when ", "where "] {
            if q.hasPrefix(banned) { return false }
        }
        guard isBinary else { return true } // yesNo mode: yes/no phrasing is the contract
        // Binary mode: a yes/no-shaped question without an either/or pivot
        // cannot be answered by two option labels
        let yesNoStarts = ["do you", "did you", "does ", "have you", "has ", "are you", "is ", "was ", "were you", "would you", "will you", "can you", "could you", "should you"]
        if yesNoStarts.contains(where: { q.hasPrefix($0) }) && !q.contains(" or ") {
            return false
        }
        return true
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
