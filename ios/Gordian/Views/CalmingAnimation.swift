// Breathing verdict animation — port of ui/components/CalmingUpliftingAnimation.kt
// (breathing gold core, expanding ripples, floating embers, breath text)

import SwiftUI

private struct Particle {
    let xSeed: CGFloat
    let speed: CGFloat
    let size: CGFloat
}

struct CalmingAnimation: View {
    // Vertical position of the breathing core (0 = top, 1 = bottom). The verdict
    // screen runs the animation full-screen with the core in the upper region.
    var coreY: CGFloat = 0.5

    @State private var particles: [Particle] = (0..<25).map { _ in
        Particle(
            xSeed: CGFloat.random(in: 0...1),
            speed: CGFloat.random(in: 1.0...3.5),
            size: CGFloat.random(in: 2...5)
        )
    }
    @State private var startDate = Date()

    var body: some View {
        // 30fps cap: the slowest element is a 4s breath; full display refresh
        // (up to 120Hz) doubles-to-quadruples GPU/CPU cost for no visible gain
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            // Breathing: 4s up, 4s down (matches the Android reversed 4000ms tween)
            let breathePhase = (sin(t * .pi / 4 - .pi / 2) + 1) / 2
            let breatheScale = 0.85 + 0.30 * breathePhase
            let glowAlpha = 0.15 + 0.30 * breathePhase
            // Ripples on 3-second linear loops, second one offset by half
            let ripple1 = (t / 3).truncatingRemainder(dividingBy: 1)
            let ripple2 = ((t + 1.5) / 3).truncatingRemainder(dividingBy: 1)
            // Particle clock matching the Android 15s → 100 factor
            let particleFactor = (t / 15).truncatingRemainder(dividingBy: 1) * 100

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * coreY)
                    let baseRadius = min(size.width, size.height) / 4.5

                    // 1. Glowing aura
                    let glowRadius = baseRadius * 1.8 * breatheScale
                    let auraRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius,
                                          width: glowRadius * 2, height: glowRadius * 2)
                    context.fill(
                        Path(ellipseIn: auraRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color.goldPrimary.opacity(glowAlpha),
                                Color.goldPrimary.opacity(glowAlpha * 0.4),
                                .clear
                            ]),
                            center: center,
                            startRadius: 0,
                            endRadius: glowRadius
                        )
                    )

                    // 2. Expanding ripple rings — ease-out radius and a gentler fade
                    // so rings drift outward like water instead of marching linearly
                    let rippleMax = min(size.width, size.height) / 2
                    for (progress, width) in [(ripple1, 2.0), (ripple2, 1.5)] where progress > 0 {
                        let eased = 1 - pow(1 - progress, 2)
                        let radius = baseRadius + (rippleMax - baseRadius) * eased
                        let alpha = pow(1 - progress, 1.5) * 0.28
                        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2)
                        context.stroke(
                            Path(ellipseIn: rect),
                            with: .color(Color.goldPrimary.opacity(alpha)),
                            lineWidth: width
                        )
                    }

                    // 3. Floating embers
                    for particle in particles {
                        let elapsedY = (particleFactor * particle.speed).truncatingRemainder(dividingBy: 100)
                        let startY = size.height + 20
                        let currentY = startY - (elapsedY / 100) * (size.height + 40)
                        let sway = sin(particleFactor * 0.15 + particle.xSeed * 10) * 20
                        let currentX = particle.xSeed * size.width + sway

                        let topProximity = currentY / size.height
                        var alpha: CGFloat
                        if topProximity < 0.2 {
                            alpha = topProximity / 0.2
                        } else if topProximity > 0.8 {
                            alpha = (1 - topProximity) / 0.2
                        } else {
                            alpha = 1
                        }
                        alpha *= 0.6

                        if alpha > 0 {
                            let rect = CGRect(x: currentX - particle.size, y: currentY - particle.size,
                                              width: particle.size * 2, height: particle.size * 2)
                            context.fill(Path(ellipseIn: rect), with: .color(Color.goldAccent.opacity(alpha)))
                        }
                    }

                    // 4. Central peaceful core
                    let coreRadius = baseRadius * breatheScale
                    let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius,
                                          width: coreRadius * 2, height: coreRadius * 2)
                    context.fill(
                        Path(ellipseIn: coreRect),
                        with: .radialGradient(
                            Gradient(colors: [.goldAccent, .goldPrimary, .clear]),
                            center: center,
                            startRadius: 0,
                            endRadius: coreRadius
                        )
                    )
                }

                // Dark ink on the bright core (white-on-gold failed the contrast
                // check), and the two phrases crossfade with the breath instead
                // of swapping abruptly.
                GeometryReader { geo in
                    VStack(spacing: 4) {
                        // Non-overlapping fades with a quiet beat between the
                        // phrases — a simultaneous crossfade superimposes them
                        // into unreadable mush at mid-breath.
                        let inhaleOpacity = min(max((breathePhase - 0.55) / 0.2, 0), 1)
                        let exhaleOpacity = min(max((0.45 - breathePhase) / 0.2, 0), 1)
                        ZStack {
                            Text("BREATHE IN CLARITY")
                                .opacity(Double(inhaleOpacity))
                            Text("RELEASE ALL DOUBT")
                                .opacity(Double(exhaleOpacity))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.black.opacity(0.72))
                        Text("KNOT UNTIED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.black.opacity(0.42))
                    }
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: geo.size.height * coreY)
                }
            }
        }
    }
}
