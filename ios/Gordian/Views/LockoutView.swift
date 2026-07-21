// Safety lock — shown when a dilemma trips the danger screen (client keywords
// or the proxy's SENSITIVE classification), and it owns the home screen while
// active. Gold-on-black like the rest of the app; severity is carried by the
// Art Deco exclamation, the countdown, and the honest escalation warning
// (5 min, 30 min, 24 hours per repeat). Crisis resources stay present.

import SwiftUI

// Art Deco exclamation mark: double-line octagon frame, tapered column, diamond point
struct ArtDecoExclamation: View {
    var color: Color = .goldPrimary

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 2

            func octagon(_ radius: CGFloat) -> Path {
                var path = Path()
                for i in 0..<8 {
                    let angle = CGFloat(Double(i) * 45.0 - 22.5) * .pi / 180
                    let pt = CGPoint(x: center.x + radius * CoreGraphics.cos(angle),
                                     y: center.y + radius * CoreGraphics.sin(angle))
                    i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                }
                path.closeSubpath()
                return path
            }

            // Deco double frame
            context.stroke(octagon(r), with: .color(color), lineWidth: 2)
            context.stroke(octagon(r * 0.86), with: .color(color.opacity(0.45)), lineWidth: 1)

            // Tapered column
            var bar = Path()
            bar.move(to: CGPoint(x: center.x - r * 0.14, y: center.y - r * 0.48))
            bar.addLine(to: CGPoint(x: center.x + r * 0.14, y: center.y - r * 0.48))
            bar.addLine(to: CGPoint(x: center.x + r * 0.06, y: center.y + r * 0.16))
            bar.addLine(to: CGPoint(x: center.x - r * 0.06, y: center.y + r * 0.16))
            bar.closeSubpath()
            context.fill(bar, with: .color(color))

            // Diamond point
            let dy = center.y + r * 0.40
            let dr = r * 0.12
            var diamond = Path()
            diamond.move(to: CGPoint(x: center.x, y: dy - dr))
            diamond.addLine(to: CGPoint(x: center.x + dr, y: dy))
            diamond.addLine(to: CGPoint(x: center.x, y: dy + dr))
            diamond.addLine(to: CGPoint(x: center.x - dr, y: dy))
            diamond.closeSubpath()
            context.fill(diamond, with: .color(color))
        }
    }
}

struct LockoutView: View {
    var viewModel: SessionViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, (viewModel.lockoutUntil ?? .now).timeIntervalSince(timeline.date))
            VStack(spacing: 24) {
                Spacer()

                ArtDecoExclamation()
                    .frame(width: 60, height: 60)

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
                        .foregroundColor(.goldPrimary)
                        .padding(.top, 4)

                    Text(escalationWarning)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.goldPrimary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .gordianCard(borderColor: Color.goldPrimary.opacity(0.35))

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
