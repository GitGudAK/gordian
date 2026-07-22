// Crisis path — shown when a dilemma involves self-harm (client phrase screen
// or the server's self_harm classification). Support, never punishment: no
// lockout, no strikes, no countdown. Calm gold, direct help.

import SwiftUI

struct CrisisView: View {
    var viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            KnotGlyph(color: .goldPrimary)
                .frame(width: 52, height: 52)

            Text("TAKE A MOMENT")
                .font(.system(size: 20, weight: .heavy))
                .tracking(2)
                .foregroundColor(.textLight)

            VStack(spacing: 14) {
                Text("What you wrote sounds heavy. Gordian is a small decision exercise, and this deserves real support from a real person.")
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(.textLight)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Free, confidential, any hour:")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)

                HStack(spacing: 12) {
                    Link(destination: URL(string: "tel:988")!) {
                        Text("Call 988")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Color.goldPrimary))
                    }
                    Link(destination: URL(string: "sms:988")!) {
                        Text("Text 988")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.goldPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().stroke(Color.goldPrimary.opacity(0.6), lineWidth: 1))
                    }
                }

                Text("988 is the Suicide and Crisis Lifeline in the US. Outside the US, your local emergency number can connect you.")
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .gordianCard(borderColor: Color.goldPrimary.opacity(0.3))

            Button {
                viewModel.cancelPreparing()
            } label: {
                Text("Back")
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
