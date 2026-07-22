// HOME state — port of FocusTabScreen's hero + scenario entry + CTA

import SwiftUI

struct FocusHomeView: View {
    var viewModel: SessionViewModel
    var speech: SpeechCoordinator
    @State private var textInput = ""
    @FocusState private var fieldFocused: Bool

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
            .padding(.bottom, 24)
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
    }

    private func startSetup() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.startDilemmaSetup(scenario: trimmed)
    }
}
