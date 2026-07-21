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
                        Text("SECONDS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(.goldPrimary)
                    }
                }
                .frame(width: 160, height: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(viewModel.countdownSeconds) seconds remaining")

                Text("\u{201C}\(viewModel.dilemmaScenario.isEmpty ? viewModel.selectedTopic.description : viewModel.dilemmaScenario)\u{201D}")
                    .font(.footnote.italic())
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }

            // 2. Question card
            VStack {
                Text("QUESTION \(min(viewModel.rapidFireAnswers.count + 1, viewModel.activeQuestions.count)) OF \(viewModel.activeQuestions.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(.textMuted)

                Spacer()

                let question = viewModel.activeQuestions.indices.contains(viewModel.currentQuestionIndex)
                    ? viewModel.activeQuestions[viewModel.currentQuestionIndex]
                    : "Ready to test your gut?"
                Text(question)
                    .font(.title3.weight(.light))
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .gordianCard(cornerRadius: 32)
            .shadow(radius: 20)
            .padding(.vertical, 16)

            // 3. Bottom interaction controls (voice moves to its own experience — see spike 005/006)
            VStack(spacing: 12) {
                // Answer buttons — always two visually EQUAL options (design ticket #8:
                // a decision instrument must not bias its own readings)
                HStack(spacing: 16) {
                    let options: [String] = {
                        switch viewModel.answerMode {
                        case .yesNo: return ["No", "Yes"]
                        case .binary(let a, let b): return [a, b]
                        }
                    }()
                    ForEach(options, id: \.self) { option in
                        Button {
                            viewModel.submitRapidFireAnswer(choice: viewModel.answerMode == .yesNo ? option.uppercased() : option)
                        } label: {
                            Text(option)
                                .font(.body.weight(.bold))
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

                Button {
                    viewModel.resetActiveSimulation()
                } label: {
                    Text("End Session")
                        .font(.system(size: 13, weight: .medium))
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
