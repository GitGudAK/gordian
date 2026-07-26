// Spike 007: liquid-glass-identity
//
// Validates: given Gordian's Art-Deco dark/gold identity, when key surfaces
// adopt Liquid Glass (.glassEffect), then the brand survives the material.
// Human-judgment spike: the toggle flips each surface between the shipped
// styling and its glass counterpart; screenshots are the evidence.

#if canImport(FoundationModels)

import SwiftUI

@available(iOS 26.0, *)
struct LabsGlassView: View {
    @State private var glass = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Toggle("Liquid Glass", isOn: $glass)
                    .tint(.goldPrimary)
                    .padding(.horizontal, 4)

                // Surface 1: hero brand block
                VStack(spacing: 10) {
                    Image("KnotLogo").resizable().scaledToFit().frame(width: 72, height: 72)
                    Text("GORDIAN")
                        .font(.system(size: 22, weight: .heavy)).tracking(5)
                        .foregroundColor(.goldPrimary)
                    Text("Sixty seconds to your own answer.")
                        .font(.system(size: 13)).foregroundColor(.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .modifier(GlassOrCard(glass: glass))

                // Surface 2: dilemma input card
                Text("What are you wrestling with?")
                    .font(.system(size: 16)).foregroundColor(.textMuted.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .padding(20)
                    .modifier(GlassOrCard(glass: glass))

                // Surface 3: the CTA capsule
                Group {
                    if glass {
                        Text("Untie my knot")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.goldPrimary)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .glassEffect(.regular.tint(.goldPrimary.opacity(0.35)).interactive(), in: Capsule())
                    } else {
                        Text("Untie my knot")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(Capsule().fill(LinearGradient(
                                colors: [.goldAccent, .goldPrimary], startPoint: .top, endPoint: .bottom)))
                    }
                }

                // Surface 4: verdict card fragment
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "WHY", size: 10, tracking: 1)
                    Text("Your answers leaned the same way every time the clock got short — the hesitation only appeared when you imagined explaining it to someone else.")
                        .font(.footnote).lineSpacing(5).foregroundColor(.textLight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .modifier(GlassOrCard(glass: glass))
            }
            .padding(20)
        }
        .background(Color.darkBackground)
        .navigationTitle("007 · Liquid Glass")
    }
}

// Flips a surface between shipped card styling and its Liquid Glass telling
@available(iOS 26.0, *)
private struct GlassOrCard: ViewModifier {
    let glass: Bool

    func body(content: Content) -> some View {
        if glass {
            content.glassEffect(.regular.tint(.goldPrimary.opacity(0.12)), in: RoundedRectangle(cornerRadius: 24))
        } else {
            content.gordianCard(cornerRadius: 24)
        }
    }
}

#endif
