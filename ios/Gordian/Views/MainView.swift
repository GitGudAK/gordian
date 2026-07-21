// Root scaffold — port of MainScreen + HeaderSection + BottomNavBar

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var viewModel = SessionViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel)

                Group {
                    switch viewModel.activeTab {
                    case .focus: FocusTabView(viewModel: viewModel)
                    case .insights: InsightsView(viewModel: viewModel)
                    case .calibrate: CalibrateView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNavBar(activeTab: viewModel.activeTab) { viewModel.activeTab = $0 }
            }

            if viewModel.isLoading {
                Color.black.opacity(0.6).ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(.goldPrimary)
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demoSession") {
                viewModel.startDemoSession()
            } else if ProcessInfo.processInfo.arguments.contains("-demoBinary") {
                viewModel.startDemoBinary()
            } else if ProcessInfo.processInfo.arguments.contains("-demoVerdict") {
                viewModel.startDemoVerdict()
            }
            #endif
        }
    }
}

struct HeaderView: View {
    var viewModel: SessionViewModel

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image("KnotLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(radius: 8)
                Text("Gordian")
                    .font(.system(size: 20, weight: .medium))
                    .tracking(-0.5)
                    .foregroundColor(.white)
            }

            Spacer()

            if viewModel.activeTab == .focus {
                headerButton(systemImage: "clock.arrow.circlepath") {
                    viewModel.activeTab = .insights
                }
            } else if viewModel.activeTab == .insights {
                headerButton(systemImage: "bolt") {
                    viewModel.activeTab = .focus
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func headerButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundColor(.goldPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.darkSurfaceVariant))
        }
    }
}

struct BottomNavBar: View {
    let activeTab: ActiveTab
    let onSelect: (ActiveTab) -> Void

    var body: some View {
        HStack {
            tabItem(.focus, label: "FOCUS", active: "bolt.fill", inactive: "bolt")
            tabItem(.insights, label: "INSIGHTS", active: "chart.bar.fill", inactive: "chart.bar")
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
                FocusHomeView(viewModel: viewModel, speech: speech)
            case .preparing:
                PreparingView(viewModel: viewModel)
            case .activeSession:
                ActiveSessionView(viewModel: viewModel)
            case .verdict:
                VerdictView(viewModel: viewModel)
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
}
