// HOME state — port of FocusTabScreen's hero + scenario entry + CTA

import SwiftUI
import Combine

// Publishes the keyboard's current height. The root layout ignores the
// keyboard (so the nav bar stays put); scrollable screens use this to inset
// their content, making everything reachable above the keyboard by scrolling.
@MainActor
final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self else { return }
                if note.name == UIResponder.keyboardWillHideNotification {
                    withAnimation(.easeOut(duration: 0.25)) { self.height = 0 }
                    return
                }
                if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let screen = UIScreen.main.bounds.height
                    let overlap = max(0, screen - frame.origin.y)
                    withAnimation(.easeOut(duration: 0.25)) { self.height = overlap }
                }
            }
            .store(in: &cancellables)
    }
}

struct FocusHomeView: View {
    var viewModel: SessionViewModel
    var speech: SpeechCoordinator
    @State private var textInput = ""
    @FocusState private var fieldFocused: Bool
    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Compact hero (~30%): the brand moment, then out of the way
                VStack(spacing: 10) {
                    Image("KnotLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                    Text("GORDIAN")
                        .font(.system(size: 24, weight: .heavy))
                        .tracking(5)
                        .foregroundColor(.goldPrimary)
                    Text("Sixty seconds to your own answer.")
                        .font(.system(size: 13))
                        .foregroundColor(.textMuted)

                    // Status in the hero: trial countdown, or the earned badge
                    if EntitlementManager.shared.isPurchased {
                        MembershipChip()
                            .padding(.top, 4)
                    } else if EntitlementManager.shared.isInTrial {
                        Text("FREE WEEK · \(EntitlementManager.shared.trialDaysRemaining) \(EntitlementManager.shared.trialDaysRemaining == 1 ? "DAY" : "DAYS") LEFT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(.goldPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().stroke(Color.goldPrimary.opacity(0.35), lineWidth: 1))
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 6)

                // Dilemma surface — soft, borderless, ambient (no boxes in boxes)
                VStack(alignment: .leading, spacing: 6) {
                    ZStack(alignment: .bottomTrailing) {
                        TextField(
                            "",
                            text: $textInput,
                            prompt: Text("What are you wrestling with?")
                                .font(.system(size: 16))
                                .foregroundColor(.textMuted.opacity(0.7)),
                            axis: .vertical
                        )
                        .font(.system(size: 17))
                        .lineSpacing(5)
                        .lineLimit(11...16)
                        .focused($fieldFocused)
                        .submitLabel(.go)
                        .onSubmit(startSetup)
                        .padding(20)
                        .padding(.bottom, 34)

                        Button {
                            if viewModel.isRecording {
                                speech.finishListening()
                            } else {
                                speech.startListening()
                            }
                        } label: {
                            Image(systemName: viewModel.isRecording ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 15))
                                .foregroundColor(viewModel.isRecording ? .redAccent : .goldPrimary.opacity(0.85))
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Color.white.opacity(viewModel.isRecording ? 0.02 : 0.04)))
                        }
                        .accessibilityLabel(viewModel.isRecording ? "Stop speaking" : "Speak your dilemma")
                        .padding(12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.goldPrimary.opacity(fieldFocused ? 0.22 : 0.0), lineWidth: 1)
                            .animation(.easeInOut(duration: 0.25), value: fieldFocused)
                    )

                    if viewModel.isRecording {
                        Text("Listening to your gut...")
                            .font(.system(size: 12).italic())
                            .foregroundColor(.goldPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                    }
                }

                // CTA — one warm capsule, glowing only when there's something to untie
                Button(action: startSetup) {
                    Text("Untie my knot")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textInput.isEmpty ? .textMuted.opacity(0.7) : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            Capsule().fill(
                                textInput.isEmpty
                                    ? AnyShapeStyle(Color.white.opacity(0.04))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [.goldAccent, .goldPrimary],
                                        startPoint: .top,
                                        endPoint: .bottom))
                            )
                        )
                        .shadow(color: Color.goldPrimary.opacity(textInput.isEmpty ? 0 : 0.35),
                                radius: 22, y: 6)
                        .animation(.easeInOut(duration: 0.3), value: textInput.isEmpty)
                }
                .disabled(textInput.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            // When the keyboard is up, its height becomes scrollable inset so
            // the field bottom and CTA can be scrolled above it (the root
            // layout ignores the keyboard to keep the nav bar anchored)
            .padding(.bottom, 24 + keyboard.height)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .onReceive(NotificationCenter.default.publisher(for: .speechDilemmaResult)) { note in
            if let result = note.object as? String {
                textInput = result
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusDilemmaField)) { _ in
            fieldFocused = true
        }
        #if DEBUG
        // -typingDemo: screenshot tooling — prefill and focus so the keyboard
        // state (floating CTA) can be captured headlessly
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-typingDemo") {
                textInput = "Should I take the new job or stay where I am?"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    fieldFocused = true
                }
            }
        }
        #endif
    }

    private func startSetup() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.startDilemmaSetup(scenario: trimmed)
    }
}
