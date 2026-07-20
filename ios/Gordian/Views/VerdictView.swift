// VERDICT state — port of the serene verdict card + next-step CTAs

import SwiftUI

struct VerdictView: View {
    var viewModel: SessionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Calming header
                VStack(spacing: 8) {
                    CalmingAnimation()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    Text("THE GORDIAN NODE UNTIED")
                        .font(.system(size: 24, weight: .heavy))
                        .tracking(2.5)
                        .foregroundColor(.goldPrimary)
                        .multilineTextAlignment(.center)
                    Text("BREATHE DEEPLY • COGNITIVE CLARITY RESTORED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.textLight)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)

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
                                    .font(.system(size: 13).italic())
                                    .foregroundColor(.textMuted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }
                        }

                        Text(viewModel.verdictDecision)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.goldPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        // Diagnostic pills
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text("AFFECTIVE RESPONSE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.textMuted)
                                Text(viewModel.sentimentLabel)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(.goldPrimary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.goldPrimary.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.goldPrimary.opacity(0.5), lineWidth: 1))

                            VStack(spacing: 2) {
                                Text("SENSE OF RELEASE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.textMuted)
                                Text("CALM / FREE")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.darkSurfaceVariant))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }

                        Divider().background(Color.white.opacity(0.05))

                        if !viewModel.confrontedProbe.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(text: "FINAL ALIGNING PROBE", size: 10, tracking: 1)
                                Text("\u{201C}\(viewModel.confrontedProbe)\u{201D}")
                                    .font(.system(size: 15, weight: .bold).italic())
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.goldPrimary)
                                SectionLabel(text: "GUT-LEVEL ALIGNMENT & REFLECTION", size: 10, tracking: 1)
                            }
                            Text(viewModel.aiReflection)
                                .font(.system(size: 13))
                                .lineSpacing(5)
                                .foregroundColor(.textLight)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.darkSurfaceVariant.opacity(0.3)))
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
                                Text("COMPLETE & RETURN HOME")
                                    .font(.system(size: 14, weight: .bold))
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
                                Text("VIEW IN CHRONOLOGY LOG")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color.darkSurface))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}
