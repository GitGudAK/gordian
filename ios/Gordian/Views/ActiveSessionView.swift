// ACTIVE_SESSION state — port of the 60s countdown ring, psychology card,
// sentiment wave, reflection input, and YES/NO rapid-fire controls

import SwiftUI

struct ActiveSessionView: View {
    var viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 1. Circular progress timer
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.darkSurface, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.countdownSeconds) / 60)
                        .stroke(Color.goldPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.countdownSeconds)
                    VStack(spacing: 0) {
                        Text("\(viewModel.countdownSeconds)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .contentTransition(.numericText(countsDown: true))
                        Text(viewModel.isTimerActive ? "SECONDS" : "TAP TO START")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(.goldPrimary)
                    }
                }
                .frame(width: 160, height: 160)
                .contentShape(Circle())
                .onTapGesture {
                    if viewModel.isTimerActive {
                        viewModel.pauseTimer()
                    } else {
                        viewModel.startTimer()
                    }
                }

                Text("\u{201C}\(viewModel.dilemmaScenario.isEmpty ? viewModel.selectedTopic.description : viewModel.dilemmaScenario)\u{201D}")
                    .font(.system(size: 13).italic())
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                Text("RAPID ANSWERS: \(viewModel.rapidFireAnswers.count)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.goldPrimary)
            }

            // 2. Psychology card
            VStack {
                Image(systemName: "brain")
                    .font(.system(size: 30))
                    .foregroundColor(.goldPrimary)

                Spacer()

                let question = viewModel.activeQuestions.indices.contains(viewModel.currentQuestionIndex)
                    ? viewModel.activeQuestions[viewModel.currentQuestionIndex]
                    : "Ready to test your gut?"
                Text(question)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.vertical, 12)
                    // The question must never truncate: keep its full height and let
                    // spacers/card padding absorb vertical compression instead
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .id(viewModel.currentQuestionIndex)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.18), value: viewModel.currentQuestionIndex)

                Spacer()

                // Indicator dots
                HStack(spacing: 6) {
                    ForEach(viewModel.activeQuestions.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == viewModel.currentQuestionIndex ? Color.goldPrimary : Color.white.opacity(0.2))
                            .frame(width: idx == viewModel.currentQuestionIndex ? 8 : 6,
                                   height: idx == viewModel.currentQuestionIndex ? 8 : 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .gordianCard(cornerRadius: 32)
            .shadow(radius: 20)
            .padding(.vertical, 16)

            // 3. Bottom interaction controls (voice moves to its own experience — see spike 005/006)
            VStack(spacing: 12) {
                // Answer buttons — NO/YES, or the dilemma's own two options
                HStack(spacing: 16) {
                    switch viewModel.answerMode {
                    case .yesNo:
                        Button {
                            viewModel.submitRapidFireAnswer(choice: "NO")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.redAccent)
                                Text("No")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color.darkSurfaceVariant))
                        }

                        Button {
                            viewModel.submitRapidFireAnswer(choice: "YES")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                                Text("Yes")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color.goldPrimary))
                        }

                    case .binary(let optionA, let optionB):
                        // Equal styling on purpose — no visual bias between the two options
                        ForEach([optionA, optionB], id: \.self) { option in
                            Button {
                                viewModel.submitRapidFireAnswer(choice: option)
                            } label: {
                                Text(option)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.goldPrimary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.6)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.darkSurfaceVariant))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.goldPrimary.opacity(0.6), lineWidth: 1.5))
                            }
                        }
                    }
                }

                Button {
                    viewModel.resetActiveSimulation()
                } label: {
                    Text("ABORT SESSION")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.redAccent.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}
