// Safety lock — shown when a dilemma trips the danger screen (client keywords
// or the proxy's SENSITIVE classification). Serious, not decorative: warning
// red, a countdown, and an honest escalation warning (5 min, 30 min, 24 hours
// per repeat). Crisis resources stay present. Never gamified.

import SwiftUI

struct LockoutView: View {
    var viewModel: SessionViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, (viewModel.lockoutUntil ?? .now).timeIntervalSince(timeline.date))
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.redAccent)

                Text("SESSIONS LOCKED")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.textLight)

                VStack(spacing: 14) {
                    Text("Gordian is built for everyday dilemmas. What you described could hurt you or someone else.")
                        .font(.system(size: 14))
                        .foregroundColor(.textLight)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(timeString(remaining))
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundColor(.redAccent)
                        .padding(.top, 4)

                    Text(escalationWarning)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redAccent.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .gordianCard(borderColor: Color.redAccent.opacity(0.4))

                Text("If any part of this involves harming yourself, you deserve real support right now. In the US, call or text 988.")
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

    // Honest escalation copy: matches what triggerLockout actually enforces.
    private var escalationWarning: String {
        switch viewModel.lockoutStrikes {
        case 0, 1:
            return "Repeated attempts will lock sessions for 30 minutes, then a full day."
        case 2:
            return "Another attempt will lock sessions for a full day."
        default:
            return "Repeated attempts keep sessions locked for a full day at a time."
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
