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
    var clarifyingQuestions: [String] = []
    var currentClarifyingQuestionIndex = 0
    var clarifyingAnswers: [String] = []
    var isGeneratingQuestions = false
    var rapidFireAnswers: [RapidFireAnswer] = []
    var confrontedProbe = ""

    // MARK: - Verdict / analysis

    var sentimentLabel = "UNSURE"
    var aiReflection = "Tap YES or NO rapidly, or hold Mic to reflect your raw reaction."
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
        clarifyingQuestions = []
        currentClarifyingQuestionIndex = 0
        clarifyingAnswers = []
        rapidFireAnswers = []
        confrontedProbe = ""
        focusScreenState = .clarifying
        generateClarifyingQuestions()
    }

    private func generateClarifyingQuestions() {
        let scenario = dilemmaScenario
        guard let client else {
            clarifyingQuestions = [
                "What is the single greatest risk holding you back from making this choice?",
                "If both options cost the same and had the same social status, which would you pick?"
            ]
            return
        }

        Task {
            isGeneratingQuestions = true
            defer { isGeneratingQuestions = false }
            let system = "You are an expert cognitive psychologist specializing in decision-making under intense pressure. "
                + "The user has described their dilemma: '\(scenario)'. "
                + "Assess whether you need clarifying questions to understand their scenario, emotional state, or core trade-offs better before formulating deep psychological bypass questions. "
                + "If clarifying questions are indeed needed, generate exactly 1 or 2 short, direct, psychologically targeted clarifying questions (maximum 12 words each). "
                + "If the scenario is already extremely clear, detailed, and specific, and no clarifying questions are needed to get to the core, return an empty JSON array: []. "
                + "Format your response as a JSON array of strings: [\"Question 1?\", \"Question 2?\"] or []. "
                + "Output ONLY the JSON array. No markdown, no formatting, no code blocks."
            do {
                let generated = try await client.generateStringArray(
                    system: system,
                    user: "Generate clarifying questions only if needed, otherwise empty array.",
                    temperature: 0.7
                )
                if generated.isEmpty {
                    clarifyingQuestions = []
                    generateBypassQuestionsAndStart()
                } else {
                    clarifyingQuestions = generated
                    currentClarifyingQuestionIndex = 0
                }
            } catch {
                clarifyingQuestions = [
                    "What is the single greatest risk holding you back from making this choice?",
                    "If both options cost the same and had the same social status, which would you pick?"
                ]
            }
        }
    }

    func submitClarifyingAnswer(_ answer: String) {
        clarifyingAnswers.append(answer.isEmpty ? "Skipped" : answer)
        let nextIndex = currentClarifyingQuestionIndex + 1
        if nextIndex < clarifyingQuestions.count {
            currentClarifyingQuestionIndex = nextIndex
        } else {
            generateBypassQuestionsAndStart()
        }
    }

    func skipClarifications() {
        generateBypassQuestionsAndStart()
    }

    private func beginSession(with questions: [String]) {
        let title = dilemmaScenario.count > 25 ? String(dilemmaScenario.prefix(25)) + "..." : dilemmaScenario
        selectedTopic = SimulationTopic(title: title, description: dilemmaScenario, defaultQuestions: questions)
        activeQuestions = questions
        currentQuestionIndex = 0
        focusScreenState = .activeSession
        countdownSeconds = 60
        startTimer()
    }

    private func generateBypassQuestionsAndStart() {
        let scenario = dilemmaScenario
        let qaPairs = zip(clarifyingQuestions, clarifyingAnswers)
            .map { "Q: \($0) -> A: \($1)" }
            .joined(separator: "\n")

        guard let client else {
            beginSession(with: Self.fallbackBypassQuestions)
            return
        }

        Task {
            isGeneratingQuestions = true
            defer { isGeneratingQuestions = false }
            let system = "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass. "
                + "The user has a dilemma: '\(scenario)'.\n"
                + "Insights gathered from clarification dialogue:\n\(qaPairs)\n"
                + "Generate exactly 12 rapid-fire, high-intensity bypass questions (maximum 10 words each, answers should be Yes or No) "
                + "designed to bypass the analytical brain, force an immediate gut response, and highlight subconscious desires or core fears.\n"
                + "Format your response as a JSON array of strings: [\"Question 1?\", \"Question 2?\", ..., \"Question 12?\"] "
                + "Output ONLY the JSON array. No markdown, no formatting, no code blocks."
            do {
                let generated = try await client.generateStringArray(
                    system: system,
                    user: "Generate exactly 12 psychological bypass questions based on the dilemma and dialogue.",
                    temperature: 0.8
                )
                beginSession(with: generated.isEmpty ? Self.fallbackBypassQuestions : generated)
            } catch {
                beginSession(with: Self.fallbackBypassQuestions)
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
        confrontedProbe = ""
        rapidFireAnswers = []
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
        let sentiment: String
        let analysis: String
        let probe: String
    }

    func evaluateFullSessionAndLog() {
        pauseTimer()
        focusScreenState = .verdict

        let scenario = dilemmaScenario
        let clarifyingQA = zip(clarifyingQuestions, clarifyingAnswers)
            .map { "Q: \($0) -> A: \($1)" }
            .joined(separator: "\n")
        let rapidFireQA = rapidFireAnswers.enumerated()
            .map { index, answer in
                "\(index + 1). Q: \(answer.question) -> Response: \(answer.choice) \(answer.reflectionText.isEmpty ? "" : "(Reflection: \(answer.reflectionText))")"
            }
            .joined(separator: "\n")

        guard let client else {
            let analysis = "You have survived the 60-second high-intensity pressure bypass. Your subconscious has processed the raw trade-offs. The path of least regret is calling you. Go forth with confidence."
            applyVerdict(
                sentiment: "DECIDED",
                analysis: analysis,
                probe: "Are you ready to commit to this path with absolute certainty?",
                logAnalysis: analysis
            )
            return
        }

        Task {
            isLoading = true
            defer { isLoading = false }
            let clarText = clarifyingQA.isEmpty ? "None (Bypassed clarifying step)" : clarifyingQA
            let rfText = rapidFireQA.isEmpty ? "None (User was silent during rapid-fire)" : rapidFireQA
            let system = "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass and final decisional resolution. "
                + "The user has this dilemma: '\(scenario)'.\n"
                + "Dialogue where we clarified their dilemma:\n\(clarText)\n"
                + "During a high-pressure 60-second rapid-fire session, they gave the following reactions:\n\(rfText)\n\n"
                + "Analyze their answers deeply. Look for inconsistencies, emotional triggers, subconscious patterns, and where their gut stance truly lies versus their rationalizations. "
                + "Synthesize this into a final definitive diagnostic breakthrough (The Gordian Verdict). "
                + "Your response MUST be in JSON format with exactly three string fields:\n"
                + "1. \"sentiment\": A single short status or affective state representing their emotional stance (e.g., 'CONFRONTED', 'RESOLVED', 'EMERGENT CLARITY', 'DIVIDED GUTS').\n"
                + "2. \"analysis\": A powerful, deep, compassionate 3-4 sentence psychological breakdown showing them what their gut actually wants and how to untie the knot.\n"
                + "3. \"probe\": A final provoking, empowering query or action step for them to move forward.\n"
                + "Output ONLY the JSON object. Do not include markdown or formatting."
            do {
                let verdict = try await client.generateObject(
                    VerdictPayload.self,
                    fields: ["sentiment", "analysis", "probe"],
                    system: system,
                    user: "Synthesize a final Gordian Verdict and return JSON.",
                    temperature: 0.8
                )
                applyVerdict(
                    sentiment: verdict.sentiment.uppercased(),
                    analysis: verdict.analysis,
                    probe: verdict.probe,
                    logAnalysis: "\(verdict.analysis)\n\n**CONFRONTED PROBE:** \(verdict.probe)"
                )
            } catch {
                let analysis = "The 60s pressure session has concluded. Your subconscious has spoken through the rapid answers. Move forward without looking back."
                applyVerdict(
                    sentiment: "DECIDED",
                    analysis: analysis,
                    probe: "Are you ready to commit to this path with absolute certainty?",
                    logAnalysis: analysis
                )
            }
        }
    }

    private func applyVerdict(sentiment: String, analysis: String, probe: String, logAnalysis: String) {
        sentimentLabel = sentiment
        aiReflection = analysis
        confrontedProbe = probe
        insert(DecisionLog(
            simulationTitle: selectedTopic.title,
            question: "Gordian Knot Untied",
            choice: "CALM / FREE",
            sentiment: sentiment,
            reflection: "Completed 60s session with \(rapidFireAnswers.count) responses.",
            aiAnalysis: logAnalysis
        ))
    }

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
