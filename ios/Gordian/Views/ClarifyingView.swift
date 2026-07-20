// CLARIFYING state — port of FocusTabScreen's clarification probe flow

import SwiftUI

struct ClarifyingView: View {
    var viewModel: SessionViewModel
    var speech: SpeechCoordinator
    @State private var clarifyingInput = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 42))
                        .foregroundColor(.goldPrimary)
                    Text("COGNITIVE CLARIFICATION")
                        .font(.system(size: 20, weight: .heavy))
                        .tracking(2)
                        .foregroundColor(.goldPrimary)
                        .multilineTextAlignment(.center)
                    Text("THE ENGINE IS UNRAVELING YOUR DILEMMA")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.textMuted)
                }
                .padding(.vertical, 12)

                if viewModel.isGeneratingQuestions || viewModel.clarifyingQuestions.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.goldPrimary)
                        SectionLabel(text: "FORMULATING PROBES...")
                        Text("The deep psychological engine is drilling into your cognitive knot to generate hyper-personalized bypass questions.")
                            .font(.system(size: 11))
                            .foregroundColor(.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .gordianCard(borderColor: Color.goldPrimary.opacity(0.2))
                } else {
                    let index = viewModel.currentClarifyingQuestionIndex
                    let question = viewModel.clarifyingQuestions.indices.contains(index) ? viewModel.clarifyingQuestions[index] : ""

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SectionLabel(text: "CLARIFICATION PROBE", size: 10, tracking: 1)
                            Spacer()
                            Text("STEP \(index + 1) OF \(viewModel.clarifyingQuestions.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.textMuted)
                        }

                        Text(question)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Divider().background(Color.white.opacity(0.05))

                        TextField(
                            "",
                            text: $clarifyingInput,
                            prompt: Text("Answer honestly, or use voice. Keep it raw...")
                                .font(.system(size: 13))
                                .foregroundColor(.textMuted),
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .focused($fieldFocused)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .modifier(GordianFieldStyle(focused: fieldFocused))

                        if viewModel.isRecording {
                            Text("Listening to your voice...")
                                .font(.system(size: 11).italic())
                                .foregroundColor(.goldPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.goldPrimary.opacity(0.05)))
                        }

                        HStack(spacing: 10) {
                            Button {
                                if viewModel.isRecording {
                                    speech.finishListening()
                                } else {
                                    speech.startListening()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.isRecording ? "mic.slash.fill" : "mic.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(viewModel.isRecording ? .redAccent : .goldPrimary)
                                    Text(viewModel.isRecording ? "STOP" : "SPEAK ANSWER")
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

                            Button(action: submit) {
                                Text(index + 1 == viewModel.clarifyingQuestions.count ? "BEGIN BYPASS" : "NEXT PROBE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.goldPrimary))
                            }
                        }
                    }
                    .padding(24)
                    .gordianCard()

                    Button {
                        viewModel.skipClarifications()
                    } label: {
                        Text("SKIP CLARIFICATIONS & START SESSION")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.textMuted)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onReceive(NotificationCenter.default.publisher(for: .speechClarifyingResult)) { note in
            if let result = note.object as? String {
                clarifyingInput = result
            }
        }
    }

    private func submit() {
        viewModel.submitClarifyingAnswer(clarifyingInput)
        clarifyingInput = ""
    }
}
