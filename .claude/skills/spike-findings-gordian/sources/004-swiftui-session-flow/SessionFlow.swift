// Spike 004: Gordian 60-second session flow in SwiftUI
// Runs as a macOS window today (CLT Swift 5.4, macOS 11 SDK) — the same views move to iOS
// nearly verbatim once Xcode is installed. Ports the Android FocusScreenState flow:
// HOME → ACTIVE_SESSION (60s countdown, rapid-fire yes/no) → VERDICT.
//
// Build & run:  ./build.sh && ./SessionFlow
//
// Swift 5.4 constraints honored: no .task, no @Observable macro, no async/await —
// ObservableObject + Timer.publish, exactly what iOS 14-era SwiftUI allowed.

import SwiftUI
import Combine

// MARK: - Gordian palette (ported from ui/theme/Color.kt)

extension Color {
    static let darkBackground = Color(red: 0x08/255, green: 0x09/255, blue: 0x0B/255)
    static let darkSurface = Color(red: 0x13/255, green: 0x15/255, blue: 0x18/255)
    static let surfaceVariant = Color(red: 0x1E/255, green: 0x21/255, blue: 0x27/255)
    static let goldPrimary = Color(red: 0xD4/255, green: 0xAF/255, blue: 0x37/255)
    static let textLight = Color(red: 0xEA/255, green: 0xEA/255, blue: 0xEA/255)
    static let textMuted = Color(red: 0x9A/255, green: 0x9F/255, blue: 0xA5/255)
    static let redAccent = Color(red: 0xE0/255, green: 0x5C/255, blue: 0x5C/255)
    static let goldAccent = Color(red: 0xF1/255, green: 0xE4/255, blue: 0xC3/255)
}

// MARK: - Model (port of MainViewModel session slice)

enum FocusScreenState { case home, activeSession, verdict }

struct RapidFireAnswer { let question: String; let choice: String }

final class SessionModel: ObservableObject {
    @Published var screen: FocusScreenState = .home
    @Published var countdown: Int = 60
    @Published var questionIndex: Int = 0
    @Published var answers: [RapidFireAnswer] = []
    @Published var timerActive = false

    // Android's offline fallback bypass questions (MainViewModel.generateBypassQuestionsAndStart)
    let questions = [
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

    var currentQuestion: String { questions[questionIndex % questions.count] }

    func start() {
        answers = []
        questionIndex = 0
        countdown = 60
        timerActive = true
        screen = .activeSession
    }

    func tick() {
        guard timerActive, screen == .activeSession else { return }
        countdown -= 1
        if countdown <= 0 { finish() }
    }

    func answer(_ choice: String) {
        answers.append(RapidFireAnswer(question: currentQuestion, choice: choice))
        questionIndex += 1
    }

    func finish() {
        timerActive = false
        screen = .verdict
    }

    func reset() {
        timerActive = false
        screen = .home
    }

    // Offline verdict (port of the Android no-key fallback in evaluateFullSessionAndLog)
    var verdictSentiment: String {
        let yes = answers.filter { $0.choice == "YES" }.count
        let no = answers.filter { $0.choice == "NO" }.count
        if answers.count < 3 { return "EVASIVE" }
        return yes > no ? "EMERGENT CLARITY" : (no > yes ? "PROTECTIVE" : "DIVIDED GUTS")
    }
    var verdictAnalysis: String {
        "You survived the 60-second pressure bypass with \(answers.count) gut responses. " +
        "Your subconscious has processed the raw trade-offs. The path of least regret is calling you."
    }
    var verdictProbe: String { "Are you ready to commit to this path with absolute certainty?" }
}

// MARK: - Views

struct HomeView: View {
    @ObservedObject var model: SessionModel
    var body: some View {
        VStack(spacing: 24) {
            Text("GORDIAN").font(.system(size: 34, weight: .black, design: .serif))
                .foregroundColor(.goldPrimary).tracking(8)
            Text("60 seconds. No overthinking.\nAnswer from the gut.")
                .multilineTextAlignment(.center)
                .foregroundColor(.textMuted)
            Button(action: { model.start() }) {
                Text("UNTIE THE KNOT")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.darkBackground)
                    .padding(.horizontal, 36).padding(.vertical, 16)
                    .background(Capsule().fill(Color.goldPrimary))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct SessionView: View {
    @ObservedObject var model: SessionModel
    var progress: CGFloat { CGFloat(model.countdown) / 60 }

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().stroke(Color.surfaceVariant, lineWidth: 8).frame(width: 110, height: 110)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(model.countdown <= 10 ? Color.redAccent : Color.goldPrimary,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 110, height: 110)
                    .animation(.linear(duration: 1))
                Text("\(model.countdown)")
                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                    .foregroundColor(model.countdown <= 10 ? .redAccent : .textLight)
            }

            Text("QUESTION \(model.answers.count + 1)")
                .font(.system(size: 11, weight: .semibold)).tracking(3)
                .foregroundColor(.textMuted)

            Text(model.currentQuestion)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(.textLight)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460, minHeight: 96)
                .id(model.questionIndex)
                .transition(.opacity)

            HStack(spacing: 20) {
                answerButton("NO", color: .redAccent)
                answerButton("YES", color: .goldPrimary)
            }
            Button(action: { model.finish() }) {
                Text("End early → verdict").font(.footnote).foregroundColor(.textMuted)
            }.buttonStyle(PlainButtonStyle())
        }
    }

    func answerButton(_ label: String, color: Color) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { model.answer(label) } }) {
            Text(label)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(color)
                .frame(width: 130, height: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.darkSurface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: 1.5))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VerdictView: View {
    @ObservedObject var model: SessionModel
    var body: some View {
        VStack(spacing: 20) {
            Text("THE GORDIAN VERDICT")
                .font(.system(size: 12, weight: .semibold)).tracking(4)
                .foregroundColor(.textMuted)
            Text(model.verdictSentiment)
                .font(.system(size: 30, weight: .black, design: .serif))
                .foregroundColor(.goldPrimary)
            Text(model.verdictAnalysis)
                .foregroundColor(.textLight)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Text("“\(model.verdictProbe)”")
                .italic()
                .foregroundColor(.goldAccent)
                .multilineTextAlignment(.center)
            Text("\(model.answers.count) gut responses · \(model.answers.filter { $0.choice == "YES" }.count) YES / \(model.answers.filter { $0.choice == "NO" }.count) NO")
                .font(.footnote).foregroundColor(.textMuted)
            Button(action: { model.reset() }) {
                Text("NEW SESSION")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.darkBackground)
                    .padding(.horizontal, 26).padding(.vertical, 12)
                    .background(Capsule().fill(Color.goldPrimary))
            }.buttonStyle(PlainButtonStyle())
        }
    }
}

struct RootView: View {
    @StateObject var model = SessionModel()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            switch model.screen {
            case .home: HomeView(model: model)
            case .activeSession: SessionView(model: model)
            case .verdict: VerdictView(model: model)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .onReceive(timer) { _ in model.tick() }
    }
}

@main
struct SpikeApp: App {
    var body: some Scene {
        WindowGroup("Gordian — Spike 004") { RootView() }
    }
}
