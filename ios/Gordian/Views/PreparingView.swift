// PREPARING state — brief loading moment while Gemini generates the bypass
// questions (~7s with a key, instant fallback without). Replaced the clarifying-
// questions step, removed 2026-07-20 to keep the flow simple.

import SwiftUI

struct PreparingView: View {
    var viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 42))
                .foregroundColor(.goldPrimary)

            Text("PREPARING YOUR SESSION")
                .font(.system(size: 20, weight: .heavy))
                .tracking(2)
                .foregroundColor(.goldPrimary)
                .multilineTextAlignment(.center)

            if !viewModel.dilemmaScenario.isEmpty {
                Text("\u{201C}\(viewModel.dilemmaScenario)\u{201D}")
                    .font(.system(size: 13).italic())
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.goldPrimary)
                Text("Formulating 12 rapid-fire questions for your gut. The 60-second clock starts the moment they're ready.")
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .gordianCard(borderColor: Color.goldPrimary.opacity(0.2))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
