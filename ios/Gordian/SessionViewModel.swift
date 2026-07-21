// App state + session logic — port of MainViewModel.kt.
// StateFlow → @Observable properties; viewModelScope.launch → Task; Room → SwiftData.

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SessionViewModel {

    var modelContext: ModelContext?

    // MARK: - Navigation

    var activeTab: ActiveTab = .focus
    var focusScreenState: FocusScreenState = .home

    // MARK: - Topics (Android's availableTopics, verbatim)

    let availableTopics: [SimulationTopic] = [
        SimulationTopic(
            title: "Career Shift",
            description: "Job offer in hand, mounting anxiety about leaving your stable routine.",
            defaultQuestions: [
                "Are you choosing this out of ambition or fear?",
                "If you were forbidden from explaining this choice to anyone, would you still do it?",
                "If you flip a coin on this choice, which side do you secretly hope it lands on?",
                "Is your current stability actually growth, or is it just comfortable stagnation?",
                "Would the 80-year-old version of you regret staying or regret leaving?"
            ]
        ),
        SimulationTopic(
            title: "Meeting Loop",
            description: "Teams stuck in a circular alignment debate, bleeding hours to consensus paralysis.",
            defaultQuestions: [
                "Is this meeting meant to build a perfect plan, or to avoid individual responsibility?",
                "If we wait for 100% consensus, will our competitors ship before we agree?",
                "Is the risk of being wrong worse than the certainty of being slow?",
                "If this project fails, is it because of the decision itself, or because we took too long?",
                "Would you be willing to take full personal ownership of shipping this today?"
            ]
        ),
        SimulationTopic(
            title: "Mounting Anxiety",
            description: "Multiple browser tabs open, brain doing daily simulations, overload mounting.",
            defaultQuestions: [
                "Are these open tabs representing active progress, or visual monuments to avoidance?",
                "If you closed all tabs right now, what is the single most critical task you'd miss?",
                "Is your anxiety telling you to work harder, or is it telling you to simplify?",
                "Would 1 hour of fully focused effort do more than 5 hours of multi-tasking?",
                "Are you seeking consensus to dilute the risk of your own intuition?"
            ]
        ),
        SimulationTopic(
            title: "Micro-Decisions",
            description: "A quick daily dilemma: Buy the expensive subscription or build it yourself?",
            defaultQuestions: [
                "Are you buying this to solve a real bottleneck, or just to buy the feeling of progress?",
                "If this cost three times as much, would you still buy it?",
                "Is your time saved worth more than the dollars spent?",
                "Is this a screaming 'hell yes' or is it actually a distraction?",
                "Are you overthinking this to delay doing the real work?"
            ]
        )
    ]

    private static let fallbackBypassQuestions = [
        "Is your hesitation actually saving you, or stalling you?",
        "If no one was looking, what would your answer be?",
        "Are you choosing out of ambition or fear?",
        "Would your 80-year-old self regret choosing stagnation?",
        "Is this a screaming 'hell yes', or is it actually a distraction?",
        "Are you overthinking this to delay doing the real work?",
        "If both options cost the same, which would you pick?",
        "What is the single greatest risk holding you back?",
        "Are you seeking consensus to dilute your own risk?",
        "Is comfort more important to you than growth?",
        "What is the choice you are most afraid of making?",
        "Will you be thinking about this same problem next year?"
    ]

    var selectedTopic: SimulationTopic
    var activeQuestions: [String]
    var currentQuestionIndex = 0
    var answerMode: AnswerMode = .yesNo

    // Generic either/or questions used when there's no API key for a binary dilemma
    private static let fallbackBinaryQuestions = [
        "Which one excites you more right now?",
        "Which would you regret never trying?",
        "If both cost the same effort, which one?",
        "Which fits the life you want in five years?",
        "Which would you start tonight if forced?",
        "Which one keeps coming back to mind?",
        "If a friend had to pick for you, which?",
        "Which feels like growth, not comfort?",
        "Flip a coin — which do you secretly hope for?",
        "Which would your 80-year-old self pick?",
        "Which is the braver choice?",
        "Which feels like play, not work?"
    ]

    // MARK: - Timer

    var countdownSeconds = 60
    var isTimerActive = false
    private var timerTask: Task<Void, Never>?

    // MARK: - Voice & sentiment

    var sentimentWaveRms: Float = 0
    var isRecording = false
    var transcription = ""

    // MARK: - Dilemma setup flow

    var dilemmaScenario = ""
    var isGeneratingQuestions = false
    var rapidFireAnswers: [RapidFireAnswer] = []
    var confrontedProbe = ""

    // MARK: - Verdict / analysis

    var sentimentLabel = "UNSURE"
    var aiReflection = "Tap YES or NO rapidly, or hold Mic to reflect your raw reaction."
    var verdictDecision = ""
    var isLoading = false

    init() {
        selectedTopic = availableTopics[0]
        activeQuestions = availableTopics[0].defaultQuestions
    }

    // MARK: - API key (SharedPreferences → UserDefaults)

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    }

    func saveApiKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "gemini_api_key")
    }

    var savedApiKey: String { apiKey }

    private var client: GeminiClient? {
        let key = apiKey
        guard !key.isEmpty, key != "MY_GEMINI_API_KEY" else { return nil }
        return GeminiClient(apiKey: key)
    }

    // MARK: - Dilemma setup

    func startDilemmaSetup(scenario: String) {
        dilemmaScenario = scenario
        rapidFireAnswers = []
        confrontedProbe = ""
        focusScreenState = .preparing
        generateBypassQuestionsAndStart()
    }

    private func beginSession(with questions: [String], mode: AnswerMode) {
        let title = dilemmaScenario.count > 25 ? String(dilemmaScenario.prefix(25)) + "..." : dilemmaScenario
        selectedTopic = SimulationTopic(title: title, description: dilemmaScenario, defaultQuestions: questions)
        activeQuestions = questions
        answerMode = mode
        currentQuestionIndex = 0
        focusScreenState = .activeSession
        countdownSeconds = 60
        startTimer()
    }

    // Heuristic "X or Y" extraction for the no-key fallback (Gemini does this properly)
    private func parseBinaryOptions(from scenario: String) -> (String, String)? {
        let lower = scenario.lowercased()
        guard let orRange = lower.range(of: " or ") else { return nil }
        let punctuation = CharacterSet(charactersIn: "?.!,;")
        let beforeWords = lower[..<orRange.lowerBound].split(separator: " ")
        let afterWords = lower[orRange.upperBound...].split(separator: " ")
        guard let last = beforeWords.last, !afterWords.isEmpty else { return nil }
        let optionA = String(last).trimmingCharacters(in: punctuation)
        let optionB = afterWords.prefix(3).joined(separator: " ").trimmingCharacters(in: punctuation)
        guard optionA.count > 1, optionB.count > 1, optionA != optionB else { return nil }
        return (optionA.capitalized, optionB.capitalized)
    }

    private struct SessionPlanPayload: Decodable {
        let mode: String
        let optionA: String
        let optionB: String
        let questions: [String]
    }

    private func generateBypassQuestionsAndStart() {
        let scenario = dilemmaScenario

        guard let client else {
            if let (a, b) = parseBinaryOptions(from: scenario) {
                beginSession(with: Self.fallbackBinaryQuestions, mode: .binary(a, b))
            } else {
                beginSession(with: Self.fallbackBypassQuestions, mode: .yesNo)
            }
            return
        }

        Task {
            isGeneratingQuestions = true
            defer { isGeneratingQuestions = false }
            let system = "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass. "
                + "The user has a dilemma: '\(scenario)'.\n"
                + "STEP 1 — Classify the dilemma. If it is a choice between two named alternatives (e.g. 'Spanish or German', 'take the job or stay'), set mode='BINARY' and extract short Title Case labels (1-3 words) as optionA and optionB. "
                + "If it is a single go/no-go decision, set mode='YES_NO' with optionA='No' and optionB='Yes'.\n"
                + "STEP 2 — Generate exactly 12 rapid-fire, high-intensity bypass questions (maximum 12 words each) designed to bypass the analytical brain and force an immediate gut response. "
                + "CRITICAL: every question must be answerable INSTANTLY by tapping one of the two option buttons. "
                + "For BINARY mode, frame questions like 'Which one would you start tonight?' or 'Which would you regret never trying?' — never yes/no phrasing. "
                + "For YES_NO mode, use yes/no phrasing.\n"
                + "Return JSON: {\"mode\": ..., \"optionA\": ..., \"optionB\": ..., \"questions\": [12 strings]}. Output ONLY the JSON object."
            do {
                let plan = try await client.generateObject(
                    SessionPlanPayload.self,
                    schema: .object(
                        properties: [
                            "mode": .string,
                            "optionA": .string,
                            "optionB": .string,
                            "questions": .stringArray
                        ],
                        required: ["mode", "optionA", "optionB", "questions"]
                    ),
                    system: system,
                    user: "Classify the dilemma and generate the 12 bypass questions as JSON.",
                    temperature: 0.8
                )
                let mode: AnswerMode = (plan.mode.uppercased() == "BINARY" && !plan.optionA.isEmpty && !plan.optionB.isEmpty)
                    ? .binary(plan.optionA, plan.optionB)
                    : .yesNo
                let fallback = mode == .yesNo ? Self.fallbackBypassQuestions : Self.fallbackBinaryQuestions
                beginSession(with: plan.questions.isEmpty ? fallback : plan.questions, mode: mode)
            } catch {
                if let (a, b) = parseBinaryOptions(from: scenario) {
                    beginSession(with: Self.fallbackBinaryQuestions, mode: .binary(a, b))
                } else {
                    beginSession(with: Self.fallbackBypassQuestions, mode: .yesNo)
                }
            }
        }
    }

    // MARK: - Timer

    func startTimer() {
        guard !isTimerActive else { return }
        isTimerActive = true
        timerTask = Task {
            while countdownSeconds > 0 && isTimerActive {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdownSeconds -= 1
            }
            if countdownSeconds == 0 {
                isTimerActive = false
                evaluateFullSessionAndLog()
            }
        }
    }

    func pauseTimer() {
        isTimerActive = false
        timerTask?.cancel()
        timerTask = nil
    }

    func resetActiveSimulation() {
        pauseTimer()
        countdownSeconds = 60
        currentQuestionIndex = 0
        activeQuestions = selectedTopic.defaultQuestions
        transcription = ""
        sentimentLabel = "UNSURE"
        aiReflection = "Tap YES or NO rapidly, or hold Mic to reflect your raw reaction."
        verdictDecision = ""
        confrontedProbe = ""
        rapidFireAnswers = []
        answerMode = .yesNo
        focusScreenState = .home
    }

    // MARK: - Rapid fire

    func updateRms(_ normalized: Float) {
        sentimentWaveRms = normalized
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
        if recording {
            transcription = "Listening to your gut..."
        }
    }

    func submitRapidFireAnswer(choice: String, customText: String = "") {
        let currentQuestion = activeQuestions.indices.contains(currentQuestionIndex) ? activeQuestions[currentQuestionIndex] : ""
        let reflectionText = customText.isEmpty ? transcription : customText
        rapidFireAnswers.append(RapidFireAnswer(
            question: currentQuestion,
            choice: choice,
            reflectionText: reflectionText == "Listening to your gut..." ? "" : reflectionText
        ))
        transcription = ""
        if !activeQuestions.isEmpty {
            currentQuestionIndex = (currentQuestionIndex + 1) % activeQuestions.count
        } else {
            currentQuestionIndex = 0
        }
    }

    // MARK: - Verdict

    private struct VerdictPayload: Decodable {
        let decision: String
        let sentiment: String
        let analysis: String
        let probe: String
    }

    // Direct answer derived from the answer tally — used when there's no API key
    // or the Gemini call fails. Returns (decision text, majority choice for the log).
    private func tallyDecision() -> (String, String) {
        let total = rapidFireAnswers.count
        if total == 0 {
            return ("No gut answers logged — the knot stays tied. Run it again and answer fast.", "REFLECT")
        }
        let left = answerMode.leftLabel
        let right = answerMode.rightLabel
        let leftCount = rapidFireAnswers.filter { $0.choice.caseInsensitiveCompare(left) == .orderedSame }.count
        let rightCount = rapidFireAnswers.filter { $0.choice.caseInsensitiveCompare(right) == .orderedSame }.count

        switch answerMode {
        case .yesNo:
            if rightCount > leftCount {
                return ("Your gut says YES — \(rightCount) of \(total) rapid answers leaned toward action.", "YES")
            }
            if leftCount > rightCount {
                return ("Your gut says NO — \(leftCount) of \(total) rapid answers pulled away.", "NO")
            }
            return ("Dead even (\(rightCount)–\(leftCount)) — your gut is genuinely split. Sit with the probe below.", "REFLECT")
        case .binary:
            if rightCount > leftCount {
                return ("Your gut picked \(right.uppercased()) — \(rightCount) of \(total) rapid answers.", right)
            }
            if leftCount > rightCount {
                return ("Your gut picked \(left.uppercased()) — \(leftCount) of \(total) rapid answers.", left)
            }
            return ("Dead even between \(left) and \(right) — your gut is genuinely split. Sit with the probe below.", "REFLECT")
        }
    }

    func evaluateFullSessionAndLog() {
        pauseTimer()
        focusScreenState = .verdict

        let scenario = dilemmaScenario
        let rapidFireQA = rapidFireAnswers.enumerated()
            .map { index, answer in
                "\(index + 1). Q: \(answer.question) -> Response: \(answer.choice) \(answer.reflectionText.isEmpty ? "" : "(Reflection: \(answer.reflectionText))")"
            }
            .joined(separator: "\n")

        guard let client else {
            let (decision, majority) = tallyDecision()
            let analysis = "That tally is your subconscious talking — 60 seconds is too fast for rationalizing. Trust the direction it pointed."
            applyVerdict(
                decision: decision,
                majorityChoice: majority,
                sentiment: "DECIDED",
                analysis: analysis,
                probe: "What is the first concrete step, and when will you take it?",
                logAnalysis: analysis
            )
            return
        }

        Task {
            isLoading = true
            defer { isLoading = false }
            let rfText = rapidFireQA.isEmpty ? "None (User was silent during rapid-fire)" : rapidFireQA
            let system = "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass and final decisional resolution. "
                + "The user has this dilemma: '\(scenario)'.\n"
                + "During a high-pressure 60-second rapid-fire session, they gave the following reactions:\n\(rfText)\n\n"
                + "Analyze their answers deeply. Look for inconsistencies, emotional triggers, subconscious patterns, and where their gut stance truly lies versus their rationalizations. "
                + "Synthesize this into a final definitive verdict (The Gordian Verdict). "
                + "Your response MUST be in JSON format with exactly four string fields:\n"
                + "1. \"decision\": THE answer. One direct, decisive sentence answering the user's dilemma in their own terms (max 15 words). If the dilemma is a choice between two options, NAME the winner. No hedging, no mysticism. Example: 'Learn Spanish.' or 'Take the startup job.'\n"
                + "2. \"sentiment\": A single short affective state (e.g., 'RESOLVED', 'EMERGENT CLARITY', 'DIVIDED GUTS').\n"
                + "3. \"analysis\": 2-3 plain, concrete sentences explaining WHY that is their answer, referencing their actual rapid-fire responses. Everyday language — no jargon, no 'cognitive alignment' talk.\n"
                + "4. \"probe\": One practical follow-up question that pushes them toward the first concrete step.\n"
                + "Output ONLY the JSON object. Do not include markdown or formatting."
            do {
                let verdict = try await client.generateObject(
                    VerdictPayload.self,
                    fields: ["decision", "sentiment", "analysis", "probe"],
                    system: system,
                    user: "Synthesize a final Gordian Verdict and return JSON.",
                    temperature: 0.8
                )
                let (_, majority) = tallyDecision()
                applyVerdict(
                    decision: verdict.decision,
                    majorityChoice: majority,
                    sentiment: verdict.sentiment.uppercased(),
                    analysis: verdict.analysis,
                    probe: verdict.probe,
                    logAnalysis: "\(verdict.analysis)\n\n**CONFRONTED PROBE:** \(verdict.probe)"
                )
            } catch {
                let (decision, majority) = tallyDecision()
                let analysis = "The AI verdict was unavailable, so this is the raw tally of your answers. 60 seconds is too fast for rationalizing — trust the direction it pointed."
                applyVerdict(
                    decision: decision,
                    majorityChoice: majority,
                    sentiment: "DECIDED",
                    analysis: analysis,
                    probe: "What is the first concrete step, and when will you take it?",
                    logAnalysis: analysis
                )
            }
        }
    }

    private func applyVerdict(decision: String, majorityChoice: String, sentiment: String, analysis: String, probe: String, logAnalysis: String) {
        verdictDecision = decision
        sentimentLabel = sentiment
        aiReflection = analysis
        confrontedProbe = probe
        insert(DecisionLog(
            simulationTitle: selectedTopic.title,
            question: dilemmaScenario.isEmpty ? "Gordian Knot Untied" : dilemmaScenario,
            choice: majorityChoice,
            sentiment: sentiment,
            reflection: "\(rapidFireAnswers.count) answers",
            aiAnalysis: logAnalysis,
            decision: decision
        ))
    }

    #if DEBUG
    // Launch-argument hooks (-demoSession / -demoBinary / -demoVerdict) so tooling can screenshot flows
    func startDemoSession() {
        dilemmaScenario = "Should I take the startup offer?"
        beginSession(with: Self.fallbackBypassQuestions, mode: .yesNo)
    }

    func startDemoBinary() {
        dilemmaScenario = "Should I learn Spanish or German?"
        if let (a, b) = parseBinaryOptions(from: dilemmaScenario) {
            beginSession(with: Self.fallbackBinaryQuestions, mode: .binary(a, b))
        }
    }

    func startDemoVerdict() {
        dilemmaScenario = "Should I stay in the US or move back home to be closer to family?"
        let title = String(dilemmaScenario.prefix(25)) + "..."
        selectedTopic = SimulationTopic(title: title, description: dilemmaScenario, defaultQuestions: Self.fallbackBypassQuestions)
        rapidFireAnswers = [
            RapidFireAnswer(question: "Are you choosing out of ambition or fear?", choice: "YES", reflectionText: "mostly fear of missing family moments"),
            RapidFireAnswer(question: "Would your 80-year-old self regret choosing stagnation?", choice: "YES", reflectionText: ""),
            RapidFireAnswer(question: "Is comfort more important to you than growth?", choice: "NO", reflectionText: ""),
            RapidFireAnswer(question: "If no one was looking, what would your answer be?", choice: "YES", reflectionText: ""),
            RapidFireAnswer(question: "Will you be thinking about this same problem next year?", choice: "YES", reflectionText: "")
        ]
        evaluateFullSessionAndLog()
    }
    #endif

    // MARK: - Persistence (Room repository → SwiftData)

    private func insert(_ log: DecisionLog) {
        modelContext?.insert(log)
        try? modelContext?.save()
    }

    func deleteDecision(_ log: DecisionLog) {
        modelContext?.delete(log)
        try? modelContext?.save()
    }

    func clearHistory() {
        try? modelContext?.delete(model: DecisionLog.self)
        try? modelContext?.save()
    }
}
