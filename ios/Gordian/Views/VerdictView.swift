// VERDICT state — port of the serene verdict card + next-step CTAs

import SwiftUI

// Art Deco loader: a static eight-diamond ring with a baked chasing fade,
// spun by GPU rotation — no per-frame redraw, no UIKit spinner, no mask
// interaction (both ghost-rendered on some GPUs)
struct DecoLoader: View {
    var color: Color = .goldPrimary
    @State private var breathing = false

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let orbit = min(size.width, size.height) / 2 - 5
            for i in 0..<8 {
                let angle = CGFloat(Double(i) / 8 * 2 * .pi)
                let alpha = 0.15 + 0.85 * Double(i) / 7
                let pt = CGPoint(x: center.x + orbit * CoreGraphics.cos(angle),
                                 y: center.y + orbit * CoreGraphics.sin(angle))
                let r: CGFloat = 4.5
                var diamond = Path()
                diamond.move(to: CGPoint(x: pt.x, y: pt.y - r))
                diamond.addLine(to: CGPoint(x: pt.x + r, y: pt.y))
                diamond.addLine(to: CGPoint(x: pt.x, y: pt.y + r))
                diamond.addLine(to: CGPoint(x: pt.x - r, y: pt.y))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(color.opacity(alpha)))
            }
        }
        .frame(width: 46, height: 46)
        // Gentle breath (the "ghosting" was the since-removed global overlay
        // stacking a second spinner on top, not this view's animation)
        .opacity(breathing ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: breathing)
        .onAppear { breathing = true }
    }
}

// Applies the scroll-edge dissolve only when enabled — when disabled the view
// is left untouched (no mask layer, no offscreen rasterization at all)
struct EdgeFadeMask: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.mask(
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
        } else {
            content
        }
    }
}

// Small deco diamond used as a section mark (replaces SF symbol icons)
struct DecoMark: View {
    var color: Color = .goldPrimary

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 7, height: 7)
            .rotationEffect(.degrees(45))
    }
}

// Art Deco divider: rule — diamond triplet — rule (the support page's baseline motif)
struct DecoDivider: View {
    var color: Color = .goldPrimary

    private func diamond(_ size: CGFloat, opacity: Double) -> some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
    }

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(color.opacity(0.3)).frame(height: 1)
            diamond(5, opacity: 0.6)
            diamond(9, opacity: 0.9)
            diamond(5, opacity: 0.6)
            Rectangle().fill(color.opacity(0.3)).frame(height: 1)
        }
    }
}

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
                        VStack(spacing: 18) {
                            DecoLoader()
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
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.forward.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.goldPrimary)
                                    SectionLabel(text: "NEXT STEP", size: 10, tracking: 1)
                                }
                                Text(viewModel.confrontedProbe)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.darkSurfaceVariant.opacity(0.3)))
                        }

                        // Disclaimer closes the card itself, set off by the deco divider
                        VStack(spacing: 10) {
                            DecoDivider()
                                .padding(.horizontal, 24)
                            Text("Gordian is a self-reflection exercise. This verdict mirrors your own answers and is not medical, legal, financial, or professional advice. For decisions with serious consequences, consult a qualified professional.")
                                .font(.system(size: 11))
                                .lineSpacing(4)
                                .foregroundColor(.textMuted)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 6)
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

                }
            }
                .padding(.horizontal, 24)
                // Clear the floating nav bar entirely: content scrolls to rest
                // above it, never sliced beneath it
                .padding(.bottom, 118)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            #if DEBUG
            // -scrollBottom: screenshot tooling — open the scroll at its end
            .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("-scrollBottom") ? .bottom : .top)
            #endif
            // Content dissolves at both edges instead of hard-clipping —
            // top against the header, bottom against the nav bar. Structurally
            // ABSENT while loading: the mask's offscreen rasterization leaves
            // motion trails behind animated content on some GPUs, which is the
            // "double loader" ghost.
            .modifier(EdgeFadeMask(enabled: !viewModel.isLoading))
        }
    }
}
