// Safety pause — shown when a dilemma trips the danger screen (client keywords
// or the proxy's SENSITIVE classification). Firm but calm: a 5-minute pause,
// a plain explanation, and real-support resources. Never gamified.

import SwiftUI

struct LockoutView: View {
    var viewModel: SessionViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, (viewModel.lockoutUntil ?? .now).timeIntervalSince(timeline.date))
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "pause.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.goldPrimary)

                Text("TAKE FIVE MINUTES")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.textLight)

                VStack(spacing: 14) {
                    Text("Gordian is built for everyday dilemmas. What you described could hurt you or someone else, and a 60-second gut exercise is the wrong tool for it.")
                        .font(.system(size: 14))
                        .foregroundColor(.textLight)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Sessions are paused. Use the time to step away from the screen.")
                        .font(.system(size: 13))
                        .foregroundColor(.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(timeString(remaining))
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundColor(.goldPrimary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .gordianCard(borderColor: Color.goldPrimary.opacity(0.25))

                Text("If any part of this involves harming yourself, you deserve real support right now — in the US, call or text 988.")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
            .onChange(of: remaining <= 0) { _, expired in
                if expired { viewModel.clearLockoutIfExpired() }
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
