// Root scaffold — port of MainScreen + HeaderSection + BottomNavBar

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = SessionViewModel()
    @State private var showSettings = false
    @State private var showRedeemDemo = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel, showSettings: $showSettings)

                Group {
                    switch viewModel.activeTab {
                    case .focus: FocusTabView(viewModel: viewModel)
                    case .insights: InsightsView(viewModel: viewModel)
                    case .calibrate: CalibrateView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNavBar(activeTab: viewModel.activeTab) { tab in
                    // Already on the home screen? The bolt focuses the dilemma field
                    // instead of doing nothing (one primary action, ticket #2)
                    if tab == .focus, viewModel.activeTab == .focus, viewModel.focusScreenState == .home {
                        NotificationCenter.default.post(name: .focusDilemmaField, object: nil)
                    }
                    viewModel.activeTab = tab
                }
            }

            if viewModel.isLoading {
                Color.black.opacity(0.6).ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(.goldPrimary)
            }
        }
        .sheet(isPresented: $showRedeemDemo) {
            RedeemCodeView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            viewModel.modelContext = modelContext
            FollowUpManager.shared.refreshScheduledContent()
            EntitlementManager.shared.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-expireTrial") {
                EntitlementManager.shared.debugExpireTrial()
            } else if ProcessInfo.processInfo.arguments.contains("-resetTrial") {
                EntitlementManager.shared.debugResetTrial()
            }
            if ProcessInfo.processInfo.arguments.contains("-demoLive") {
                viewModel.startDemoLive()
            } else if ProcessInfo.processInfo.arguments.contains("-demoSession") {
                viewModel.startDemoSession()
            } else if ProcessInfo.processInfo.arguments.contains("-demoBinary") {
                viewModel.startDemoBinary()
            } else if ProcessInfo.processInfo.arguments.contains("-demoVerdict") {
                viewModel.startDemoVerdict()
            } else if ProcessInfo.processInfo.arguments.contains("-demoSensitive") {
                viewModel.startDemoSensitive()
            } else if ProcessInfo.processInfo.arguments.contains("-demoTooBig") {
                viewModel.startDemoTooBig()
            } else if ProcessInfo.processInfo.arguments.contains("-demoRedeem") {
                showRedeemDemo = true
            } else if ProcessInfo.processInfo.arguments.contains("-tabLogs") {
                viewModel.activeTab = .insights
            } else if ProcessInfo.processInfo.arguments.contains("-tabGuides") {
                viewModel.activeTab = .calibrate
            }
            #endif
        }
    }
}

struct HeaderView: View {
    var viewModel: SessionViewModel
    @Binding var showSettings: Bool

    // The home screen carries the brand in its hero — showing it here too says it twice (ticket #12)
    private var showBrand: Bool {
        !(viewModel.activeTab == .focus && viewModel.focusScreenState == .home)
    }

    var body: some View {
        HStack {
            if showBrand {
                HStack(spacing: 12) {
                    Image("KnotLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                    Text("Gordian")
                        .font(.system(size: 20, weight: .medium))
                        .tracking(-0.5)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundColor(.textMuted)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.darkSurfaceVariant))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// Simplified brand mark for small sizes: two interlocked diamonds, echoing the
// Art Deco diamond motifs of the full knot art (which muddies below ~40pt)
struct KnotGlyph: View {
    var color: Color = .black

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) * 0.34
            let offset = r * 0.55
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let lineWidth = min(size.width, size.height) * 0.1
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            func diamond(at c: CGPoint) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: c.x, y: c.y - r))
                path.addLine(to: CGPoint(x: c.x + r, y: c.y))
                path.addLine(to: CGPoint(x: c.x, y: c.y + r))
                path.addLine(to: CGPoint(x: c.x - r, y: c.y))
                path.closeSubpath()
                return path
            }

            let left = CGPoint(x: center.x - offset, y: center.y)
            let right = CGPoint(x: center.x + offset, y: center.y)
            context.stroke(diamond(at: left), with: .color(color), style: style)
            context.stroke(diamond(at: right), with: .color(color), style: style)
        }
    }
}

struct BottomNavBar: View {
    let activeTab: ActiveTab
    let onSelect: (ActiveTab) -> Void

    var body: some View {
        HStack {
            tabItem(.insights, label: "LOGS", active: "chart.bar.fill", inactive: "chart.bar")

            // Big central start-session button, raised above the bar
            Button {
                onSelect(.focus)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.goldPrimary)
                        .frame(width: 62, height: 62)
                        .shadow(color: Color.goldPrimary.opacity(0.45), radius: 12, y: 2)
                    Circle()
                        .stroke(Color.darkBackground, lineWidth: 4)
                        .frame(width: 62, height: 62)
                    KnotGlyph()
                        .frame(width: 30, height: 30)
                }
                .offset(y: -14)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Start session")

            tabItem(.calibrate, label: "GUIDES", active: "book.fill", inactive: "book")
        }
        .frame(height: 64)
        .background(Color.darkBackground)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.05)), alignment: .top)
    }

    private func tabItem(_ tab: ActiveTab, label: String, active: String, inactive: String) -> some View {
        let isSelected = activeTab == tab
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? active : inactive)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(isSelected ? .goldPrimary : .textMuted)
            .frame(maxWidth: .infinity)
        }
    }
}

// Focus tab: owns the speech coordinator and routes results by screen state,
// matching FocusTabScreen's currentOnResult behavior
struct FocusTabView: View {
    var viewModel: SessionViewModel
    @State private var speech = SpeechCoordinator()
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch viewModel.focusScreenState {
            case .home:
                // Trial over + nothing purchased → the paywall replaces home.
                // A session already in flight (below) always gets to finish.
                if EntitlementManager.shared.hasAccess {
                    FocusHomeView(viewModel: viewModel, speech: speech)
                } else {
                    PaywallView()
                }
            case .preparing:
                PreparingView(viewModel: viewModel)
            case .activeSession:
                ActiveSessionView(viewModel: viewModel)
            case .verdict:
                VerdictView(viewModel: viewModel)
            case .lockedOut:
                LockoutView(viewModel: viewModel)
            case .tooBig:
                TooBigView(viewModel: viewModel)
            }
        }
        .onAppear { configureSpeech() }
        .onDisappear { speech.stopListening() }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.darkSurfaceVariant))
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
    }

    private func configureSpeech() {
        speech.onStart = { viewModel.setRecording(true) }
        speech.onRmsChanged = { viewModel.updateRms($0) }
        speech.onPartial = { partial in
            if viewModel.focusScreenState == .activeSession {
                viewModel.transcription = partial
            }
        }
        speech.onResult = { result in
            viewModel.setRecording(false)
            if viewModel.focusScreenState == .home {
                NotificationCenter.default.post(name: .speechDilemmaResult, object: result)
            }
        }
        speech.onError = { message in
            viewModel.setRecording(false)
            showError(message)
        }
    }

    private func showError(_ message: String) {
        withAnimation { errorMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { errorMessage = nil }
        }
    }
}

extension Notification.Name {
    static let speechDilemmaResult = Notification.Name("speechDilemmaResult")
    static let focusDilemmaField = Notification.Name("focusDilemmaField")
}
