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

    // Offline question bank — 12 are drawn at random per session so repeat
    // sessions don't feel identical. The Gemini path writes dilemma-specific
    // questions instead; this is the degradation tier.
    private static let bypassQuestionBank = [
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
        "Will you be thinking about this same problem next year?",
        "If you had to decide in the next ten seconds, what wins?",
        "Are you waiting for certainty that will never come?",
        "Would you tell a friend to do this? Then why not you?",
        "Is the worst case actually survivable?",
        "Are you protecting your future, or your ego?",
        "If this fails, will you regret trying?",
        "Does the safe option secretly bore you?",
        "Are you deciding, or just delaying the decision?",
        "Would yes feel like relief or like dread?",
        "Is fear of judgment doing the choosing?",
        "What would you do with double the confidence?",
        "Has your gut already answered this?"
    ]

    private static var fallbackBypassQuestions: [String] {
        Array(bypassQuestionBank.shuffled().prefix(12))
    }

    var selectedTopic: SimulationTopic
    var activeQuestions: [String]
    var currentQuestionIndex = 0
    var answerMode: AnswerMode = .yesNo

    // Generic either/or bank — same random-12 draw as the yes/no bank
    private static let binaryQuestionBank = [
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
        "Which feels like play, not work?",
        "Which would you defend in an argument?",
        "Which one scares you in a good way?",
        "Which did you want before you started weighing?",
        "Which would you pick with no one to impress?",
        "Which one has kept you up at night?",
        "Which future self do you like more?",
        "Which choice would you make twice?",
        "Which one is the answer if this were easy?"
    ]

    private static var fallbackBinaryQuestions: [String] {
        Array(binaryQuestionBank.shuffled().prefix(12))
    }

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

    // MARK: - AI backend (Phase 3: operator proxy, no keys in the app)

    private let proxy = ProxyClient()

    // Sessions are AI-driven, always: the proxy retries a fallback model
    // server-side; if the network itself is down, the user retries — there are
    // no pre-canned session questions.
    var preparingFailed = false

    /// Component sub-decisions returned when a dilemma classifies TOO_BIG.
    var suggestedKnots: [String] = []

    /// Input wasn't a decision (NOT_A_DECISION); optional server-suggested rephrase.
    var notADecision = false
    var suggestedReframe = ""

    func retryPreparing() {
        preparingFailed = false
        generateBypassQuestionsAndStart()
    }

    func cancelPreparing() {
        preparingFailed = false
        notADecision = false
        suggestedReframe = ""
        focusScreenState = .home
    }

    // MARK: - Safety lockout (dangerous dilemmas → 5-minute pause)

    private static let lockoutKey = "gordian_lockout_until"
    private static let lockoutStrikesKey = "gordian_lockout_strikes"
    // Escalation: 5 minutes, then 30 minutes, then a full day per attempt.
    static let lockoutDurations: [TimeInterval] = [5 * 60, 30 * 60, 24 * 60 * 60]

    var lockoutUntil: Date? {
        let t = UserDefaults.standard.double(forKey: Self.lockoutKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    var isLockedOut: Bool {
        guard let until = lockoutUntil else { return false }
        return until > Date()
    }

    /// How many times the safety gate has fired on this install.
    var lockoutStrikes: Int {
        UserDefaults.standard.integer(forKey: Self.lockoutStrikesKey)
    }

    func triggerLockout() {
        let strikes = lockoutStrikes
        let duration = Self.lockoutDurations[min(strikes, Self.lockoutDurations.count - 1)]
        UserDefaults.standard.set(strikes + 1, forKey: Self.lockoutStrikesKey)
        UserDefaults.standard.set(Date().addingTimeInterval(duration).timeIntervalSince1970,
                                  forKey: Self.lockoutKey)
        focusScreenState = .lockedOut
    }

    func clearLockoutIfExpired() {
        guard !isLockedOut else { return }
        UserDefaults.standard.removeObject(forKey: Self.lockoutKey)
        // Unconditional assignment: also re-renders the home branch that shows
        // the lock screen directly (not via the .lockedOut state)
        focusScreenState = .home
    }

    // Instant client-side screen for clearly dangerous phrasing; the proxy's
    // model-level safety gate (mode=SENSITIVE) catches what keywords miss.
    private static let dangerTerms = [
        "kill", "hurt", "harm", "suicide", "end my life", "end it all",
        "weapon", "gun", "knife", "attack", "revenge", "stab", "shoot",
        "beat up", "burn down", "poison", "overdose", "steal", "rob"
    ]

    private func isDangerous(_ scenario: String) -> Bool {
        let lower = scenario.lowercased()
        return Self.dangerTerms.contains { lower.contains($0) }
    }

    // MARK: - Dilemma setup

    func startDilemmaSetup(scenario: String) {
        if isLockedOut {
            focusScreenState = .lockedOut
            return
        }
        if isDangerous(scenario) {
            triggerLockout()
            return
        }
        dilemmaScenario = scenario
        rapidFireAnswers = []
        confrontedProbe = ""
        preparingFailed = false
        notADecision = false
        suggestedReframe = ""
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

    // Heuristic "X or Y" extraction for the offline fallback (the proxy does this properly)
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

    private func generateBypassQuestionsAndStart() {
        let scenario = dilemmaScenario

        Task {
            isGeneratingQuestions = true
            defer { isGeneratingQuestions = false }
            do {
                // Prompts, classification, and the safety gate live server-side.
                let plan = try await proxy.sessionPlan(scenario: scenario)
                if plan.mode.uppercased() == "SENSITIVE" {
                    triggerLockout()
                    return
                }
                if plan.mode.uppercased() == "NOT_A_DECISION" {
                    // Not a dilemma — bounce with the server's rephrase if it offered one
                    suggestedReframe = plan.optionA
                    notADecision = true
                    return
                }
                if plan.mode.uppercased() == "TOO_BIG" {
                    // The dilemma bundles several decisions; the payload carries
                    // the component knots. Show them; the user picks one to run.
                    guard !plan.questions.isEmpty else {
                        preparingFailed = true
                        return
                    }
                    suggestedKnots = plan.questions
                    focusScreenState = .tooBig
                    return
                }
                guard !plan.questions.isEmpty else {
                    preparingFailed = true
                    return
                }
                let mode: AnswerMode = (plan.mode.uppercased() == "BINARY" && !plan.optionA.isEmpty && !plan.optionB.isEmpty)
                    ? .binary(plan.optionA, plan.optionB)
                    : .yesNo
                beginSession(with: plan.questions, mode: mode)
            } catch {
                // AI-always: no canned questions. Surface the failure; the user retries.
                preparingFailed = true
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
        // Last question answered → straight to the verdict, even mid-countdown.
        // Questions never repeat.
        if currentQuestionIndex + 1 >= activeQuestions.count {
            evaluateFullSessionAndLog()
        } else {
            currentQuestionIndex += 1
        }
    }

    // MARK: - Verdict

    // Verdict content derived from the answer tally — used when the device is
    // offline or the proxy call fails. Returns (decision, majority choice, why, next step).
    private func tallyDecision() -> (String, String, String, String) {
        let total = rapidFireAnswers.count
        let checkIn = FollowUpManager.shared.followUpsEnabled
            ? " Gordian will check in with you in 3 days."
            : ""
        if total == 0 {
            return (
                "No answers — the knot stays tied.",
                "REFLECT",
                "You didn't answer any questions, so there is nothing to read yet.",
                "Run it again and answer the instant each question appears — speed is the whole point."
            )
        }
        let left = answerMode.leftLabel
        let right = answerMode.rightLabel
        let leftCount = rapidFireAnswers.filter { $0.choice.caseInsensitiveCompare(left) == .orderedSame }.count
        let rightCount = rapidFireAnswers.filter { $0.choice.caseInsensitiveCompare(right) == .orderedSame }.count
        let winner = rightCount >= leftCount ? right : left
        let winnerCount = max(leftCount, rightCount)

        if leftCount == rightCount {
            return (
                "Dead even — your gut is genuinely split.",
                "REFLECT",
                "You answered \(left) and \(right) an equal number of times (\(leftCount)–\(rightCount)). Right now, neither option outweighs the other for you.",
                "Sharpen the question and run it again — add a deadline or a condition that would tip it."
            )
        }

        let decision: String
        switch answerMode {
        case .yesNo:
            decision = winner == right
                ? "Your gut says YES."
                : "Your gut says NO."
        case .binary:
            decision = "Your gut picked \(winner.uppercased())."
        }
        let why = "You answered \(winner.uppercased()) to \(winnerCount) of the \(total) questions. Quick answers leave no time to build justifications, so this pattern reflects your immediate preference."
        let nextStep = "Pick one small step toward it and do it today.\(checkIn)"
        return (decision, winner == right && answerMode == .yesNo ? "YES" : (answerMode == .yesNo ? "NO" : winner), why, nextStep)
    }

    func evaluateFullSessionAndLog() {
        pauseTimer()
        focusScreenState = .verdict

        let scenario = dilemmaScenario
        // Raw answers travel to the proxy; the verdict prompt lives server-side.
        let answers = rapidFireAnswers.map {
            ProxyAnswer(question: $0.question, choice: $0.choice, reflection: $0.reflectionText)
        }

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let verdict = try await proxy.verdict(scenario: scenario, answers: answers)
                let (_, majority, _, _) = tallyDecision()
                applyVerdict(
                    decision: verdict.decision,
                    majorityChoice: majority,
                    sentiment: verdict.sentiment.uppercased(),
                    analysis: verdict.analysis,
                    probe: verdict.probe,
                    logAnalysis: "\(verdict.analysis)\n\nNext step: \(verdict.probe)"
                )
            } catch {
                // Offline / limited → honest tally verdict, same as always.
                let (decision, majority, why, nextStep) = tallyDecision()
                applyVerdict(
                    decision: decision,
                    majorityChoice: majority,
                    sentiment: majority == "REFLECT" ? "SPLIT" : "DECIDED",
                    analysis: why,
                    probe: nextStep,
                    logAnalysis: why
                )
            }
        }
    }

    private func applyVerdict(decision: String, majorityChoice: String, sentiment: String, analysis: String, probe: String, logAnalysis: String) {
        verdictDecision = decision
        sentimentLabel = sentiment
        aiReflection = analysis
        confrontedProbe = probe
        let log = DecisionLog(
            simulationTitle: selectedTopic.title,
            question: dilemmaScenario.isEmpty ? "Gordian Knot Untied" : dilemmaScenario,
            choice: majorityChoice,
            sentiment: sentiment,
            reflection: "\(rapidFireAnswers.count) answers",
            aiAnalysis: logAnalysis,
            decision: decision
        )
        insert(log)
        // Close the loop: ask in a few days whether they acted on it (skip split verdicts)
        if majorityChoice != "REFLECT" {
            FollowUpManager.shared.scheduleFollowUp(decision: decision, followUpID: log.followUpID)
        }
    }

    #if DEBUG
    // Launch-argument hooks (-demoSession / -demoBinary / -demoVerdict) so tooling can screenshot flows
    func startDemoSession() {
        dilemmaScenario = "Should I take the startup offer?"
        beginSession(with: Self.fallbackBypassQuestions, mode: .yesNo)
    }

    // Runs the REAL generation path (proxy-backed AI, offline fallback otherwise)
    func startDemoLive() {
        startDilemmaSetup(scenario: "Should I move to Berlin or stay in Austin?")
    }

    func startDemoBinary() {
        dilemmaScenario = "Should I learn Spanish or German?"
        if let (a, b) = parseBinaryOptions(from: dilemmaScenario) {
            beginSession(with: Self.fallbackBinaryQuestions, mode: .binary(a, b))
        }
    }

    // Exercises the NOT_A_DECISION bounce via the real proxy round-trip
    func startDemoNonQuestion() {
        startDilemmaSetup(scenario: "I got the promotion")
    }

    // Exercises the TOO_BIG decomposition via the real proxy round-trip
    func startDemoTooBig() {
        startDilemmaSetup(scenario: "Should I sell my company, move my family to Portugal, and have another kid?")
    }

    // Exercises the safety lockout (client keyword screen fires before any network)
    func startDemoSensitive() {
        UserDefaults.standard.removeObject(forKey: Self.lockoutKey)
        startDilemmaSetup(scenario: "Should I hurt my neighbor to get revenge?")
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
        FollowUpManager.shared.cancelFollowUp(id: log.followUpID)
        modelContext?.delete(log)
        try? modelContext?.save()
    }

    func clearHistory() {
        FollowUpManager.shared.cancelAllFollowUps()
        try? modelContext?.delete(model: DecisionLog.self)
        try? modelContext?.save()
    }
}
