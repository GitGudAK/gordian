// VERDICT state — port of the serene verdict card + next-step CTAs

import SwiftUI

struct VerdictView: View {
    var viewModel: SessionViewModel

    var body: some View {
        ZStack {
            // The animation IS the screen — content floats above it. The canvas
            // extends up behind the header so ripple rings complete instead of
            // slicing at the view's top edge.
            CalmingAnimation(coreY: 0.24)
                .padding(.top, -160)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 20) {
                    // Breathing room for the orb; its own text carries the moment
                    Color.clear.frame(height: 230)

                // Verdict card
                VStack(spacing: 18) {
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.goldPrimary)
                            SectionLabel(text: "DECODING YOUR INNER INTUITION...")
                            Text("Releasing analytical hesitation and aligning your subconscious desire...")
                                .font(.system(size: 11))
                                .foregroundColor(.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Lead with the answer: their dilemma, then the decision, plainly
                        if !viewModel.dilemmaScenario.isEmpty {
                            VStack(spacing: 4) {
                                SectionLabel(text: "YOUR DILEMMA", color: .textMuted, size: 10, tracking: 1)
                                Text("\u{201C}\(viewModel.dilemmaScenario)\u{201D}")
                                    .font(.footnote.italic())
                                    .foregroundColor(.textMuted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }
                        }

                        Text(viewModel.verdictDecision)
                            .font(.title2.weight(.heavy))
                            .foregroundColor(.goldPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().background(Color.white.opacity(0.05))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.goldPrimary)
                                SectionLabel(text: "WHY", size: 10, tracking: 1)
                            }
                            Text(viewModel.aiReflection)
                                .font(.footnote)
                                .lineSpacing(5)
                                .foregroundColor(.textLight)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.darkSurfaceVariant.opacity(0.3)))

                        if !viewModel.confrontedProbe.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(text: "NEXT STEP", size: 10, tracking: 1)
                                Text(viewModel.confrontedProbe)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(24)
                .gordianCard(borderColor: Color.goldPrimary.opacity(0.35), borderWidth: 1.5)

                if !viewModel.isLoading {
                    VStack(spacing: 10) {
                        Button {
                            viewModel.resetActiveSimulation()
                        } label: {
                            HStack(spacing: 8) {
                                Text("DONE")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(1)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color.goldPrimary))
                        }

                        Button {
                            viewModel.activeTab = .insights
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.goldPrimary)
                                Text("VIEW IN LOGS")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color.darkSurface))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }

                    // Disclaimer — quiet close to the scroll, set off by a hairline
                    VStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.goldPrimary.opacity(0.25))
                            .frame(width: 44, height: 1)
                        Text("Gordian is a self-reflection exercise. This verdict mirrors your own answers and is not medical, legal, financial, or professional advice. For decisions with serious consequences, consult a qualified professional.")
                            .font(.system(size: 11))
                            .lineSpacing(4)
                            .foregroundColor(.textMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 10)
                }
            }
                .padding(.horizontal, 24)
                // Clear the floating nav bar entirely: content scrolls to rest
                // above it, never sliced beneath it
                .padding(.bottom, 118)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // Content dissolves at both edges instead of hard-clipping —
            // top against the header, bottom against the nav bar
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.90),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
