// Refusal — first harmful-intent classification. A firm line without a
// countdown: sessions remain available for everyday dilemmas, and the screen
// says plainly that repeats will pause them (the server counts strikes).

import SwiftUI

struct RefusalView: View {
    var viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ArtDecoExclamation()
                .frame(width: 56, height: 56)

            Text("GORDIAN CAN'T GO THERE")
                .font(.system(size: 20, weight: .heavy))
                .tracking(2)
                .foregroundColor(.textLight)

            VStack(spacing: 14) {
                Text("What you described could hurt someone. Gordian is built for everyday dilemmas and won't run a session on this.")
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(.textLight)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("If that was a misread of an ordinary decision, rephrase it and try again. Repeated attempts pause sessions.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.goldPrimary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .gordianCard(borderColor: Color.goldPrimary.opacity(0.35))

            Button {
                viewModel.cancelPreparing()
                NotificationCenter.default.post(name: .focusDilemmaField, object: nil)
            } label: {
                Text("Rephrase")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.goldPrimary))
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
