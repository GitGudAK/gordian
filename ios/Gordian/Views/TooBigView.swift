// Shown when a dilemma classifies TOO_BIG: it bundles several decisions, and a
// sixty-second gut session is built for exactly one. Gordian names the
// component knots; tapping one starts a session on just that knot.

import SwiftUI

struct TooBigView: View {
    var viewModel: SessionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                KnotGlyph(color: .goldPrimary)
                    .frame(width: 48, height: 48)

                Text("MORE THAN ONE KNOT")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.textLight)

                if !viewModel.dilemmaScenario.isEmpty {
                    Text("\u{201C}\(viewModel.dilemmaScenario)\u{201D}")
                        .font(.system(size: 13).italic())
                        .foregroundColor(.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                }

                Text("What you described bundles several decisions. Untie them one at a time, starting with the one that blocks the rest.")
                    .font(.system(size: 14))
                    .foregroundColor(.textLight)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(spacing: 12) {
                    ForEach(Array(viewModel.suggestedKnots.enumerated()), id: \.offset) { index, knot in
                        Button {
                            viewModel.startDilemmaSetup(scenario: knot)
                        } label: {
                            HStack(spacing: 14) {
                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                                    .foregroundColor(.goldPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().stroke(Color.goldPrimary.opacity(0.5), lineWidth: 1))
                                Text(knot)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.textLight)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.goldPrimary.opacity(0.7))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .gordianCard(borderColor: Color.goldPrimary.opacity(index == 0 ? 0.5 : 0.2))
                        }
                    }
                }

                Button {
                    viewModel.cancelPreparing()
                } label: {
                    Text("Rephrase my dilemma")
                        .font(.system(size: 13))
                        .foregroundColor(.textMuted)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
