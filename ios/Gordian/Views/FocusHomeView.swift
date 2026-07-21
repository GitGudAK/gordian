// HOME state — port of FocusTabScreen's hero + scenario entry + CTA

import SwiftUI

struct FocusHomeView: View {
    var viewModel: SessionViewModel
    var speech: SpeechCoordinator
    @State private var textInput = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero logo & title
                VStack(spacing: 8) {
                    // The mark sits directly on the background: no tile, no
                    // border, no box (asset keyed to transparency, ticket #12)
                    Image("KnotLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                    Text("GORDIAN")
                        .font(.system(size: 32, weight: .heavy))
                        .tracking(4)
                        .foregroundColor(.goldPrimary)
                    Text("BYPASS COGNITIVE OVERLOAD")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.textLight)
                    Text("Describe what you're stuck on. Answer twelve gut questions in sixty seconds. Get a straight answer.")
                        .font(.footnote)
                        .foregroundColor(.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    if EntitlementManager.shared.isInTrial {
                        Text("FREE WEEK · \(EntitlementManager.shared.trialDaysRemaining) \(EntitlementManager.shared.trialDaysRemaining == 1 ? "DAY" : "DAYS") LEFT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(.goldPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().stroke(Color.goldPrimary.opacity(0.4), lineWidth: 1))
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 12)

                // Scenario entry card
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(text: "YOUR DILEMMA")

                    TextField(
                        "",
                        text: $textInput,
                        prompt: Text("What are you wrestling with? e.g. 'Take the new job or stay?'")
                            .font(.system(size: 13))
                            .foregroundColor(.textMuted),
                        axis: .vertical
                    )
                    .lineLimit(5...8)
                    .focused($fieldFocused)
                    .submitLabel(.go)
                    .onSubmit(startSetup)
                    .modifier(GordianFieldStyle(focused: fieldFocused))

                    if viewModel.isRecording {
                        Text("Listening to your gut...")
                            .font(.system(size: 12).italic())
                            .foregroundColor(.goldPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.goldPrimary.opacity(0.05)))
                    }

                    // Voice trigger
                    Button {
                        if viewModel.isRecording {
                            speech.finishListening()
                        } else {
                            speech.startListening()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isRecording ? "mic.slash.fill" : "mic.fill")
                                .accessibilityHidden(true)
                                .font(.system(size: 15))
                                .foregroundColor(viewModel.isRecording ? .redAccent : .goldPrimary)
                            Text(viewModel.isRecording ? "STOP SPEAKING" : "SPEAK IT INSTEAD")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.isRecording ? Color.redAccent.opacity(0.2) : Color.darkSurfaceVariant))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.isRecording ? Color.redAccent : Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                .padding(20)
                .gordianCard(cornerRadius: 20)

                // CTA
                Button(action: startSetup) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 16))
                        Text("UNTIE MY KNOT")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(1)
                    }
                    .foregroundColor(textInput.isEmpty ? .textMuted : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 24)
                        .fill(textInput.isEmpty ? Color.darkSurfaceVariant : Color.goldPrimary))
                }
                .disabled(textInput.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
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
