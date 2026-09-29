import SwiftUI

/// RITUAL B — Still Water.
///
/// The only ritual that needs no camera, no ARKit and no permissions at all.
/// That is deliberate: this is the safety net. If ARKit cannot find a plane in
/// the judge's office, if the camera is denied, if the device is too old —
/// this still works, in the dark, on a train, in someone's lap.
///
/// Progress is shown ONLY as the water clearing. Never a number, never a
/// countdown. A countdown is anxiety; clearing water is patience.
///
/// In Step 1 stillness is proxied by not touching the screen — already the
/// deepest signal in the app, because SlowBloom succeeds when the child stops
/// using it. Step 2 replaces the proxy with real Core Motion data.
struct StillWaterView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let namespace: Namespace.ID
    @State private var startedAt = Date()

    private var clarity: Double {
        min(1, max(0, state.ritualAccumulated / max(1, state.ritualTarget)))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RitualBackdrop()

                // Plain values only — see the note in SlowTraceView.
                let wind = state.engine.wind
                let clear = clarity

                TimelineView(.animation) { timeline in
                    Canvas { ctx, _ in
                        draw(&ctx, size: size,
                             time: timeline.date.timeIntervalSinceReferenceDate,
                             wind: wind, clarity: clear)
                    }
                }

                VStack {
                    HStack {
                        Button { state.endRitual(completed: false) } label: {
                            Image(systemName: BloomSymbol.close)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 46, height: 46)
                                .bloomGlass(.fitting, shape: BloomShape.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Leave the ritual")
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    Spacer()

                    // The prompt fades away once the child understands. The
                    // best interface for this ritual is no interface.
                    if clarity < 0.22 {
                        VStack(spacing: 8) {
                            PromptBanner(text: BloomCopy.stillTitle)
                                .matchedGeometryEffect(id: "hud-prompt", in: namespace, isSource: true)
                            Text(BloomCopy.stillCup)
                                .font(.bloomCaption)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity)
                        .padding(.bottom, 30)
                    }
                }
                .animation(BloomMotion.sleepy(state.motionScale), value: clarity < 0.22)
            }
        }
        .onDisappear { state.engine.input = .idle }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Still water")
        .accessibilityValue("\(Int(clarity * 100)) percent clear")
        .accessibilityHint("Hold the iPad steady and do not touch the screen")
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, time: Double,
                      wind: Double, clarity c: Double) {
        let colors = WorldColors.make(dark: scheme == .dark)

        let surfaceY = size.height * 0.42
        let waterRect = CGRect(x: 0, y: surfaceY, width: size.width,
                               height: size.height - surfaceY)

        // ── Ripple amplitude damps as calm accumulates.
        let amp = (wind * 0.05 + 0.006) * (1 - c * 0.94) * Double(size.height) * 0.06

        var surface = Path()
        let steps = 44
        surface.move(to: CGPoint(x: 0, y: surfaceY))
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let x = CGFloat(f) * size.width
            let y = surfaceY
                + CGFloat(sin(f * 9.0 + time * 1.6) * amp)
                + CGFloat(sin(f * 4.3 - time * 1.05) * amp * 0.55)
                + CGFloat(sin(f * 21.0 + time * 2.6) * amp * 0.18)
            surface.addLine(to: CGPoint(x: x, y: y))
        }
        surface.addLine(to: CGPoint(x: size.width, y: size.height))
        surface.addLine(to: CGPoint(x: 0, y: size.height))
        surface.closeSubpath()

        ctx.fill(surface, with: .linearGradient(
            Gradient(colors: [colors.water.opacity(0.55 + 0.25 * c),
                              colors.water.opacity(0.16)]),
            startPoint: CGPoint(x: size.width / 2, y: waterRect.minY),
            endPoint: CGPoint(x: size.width / 2, y: waterRect.maxY)))

        // ── Reflections appear in stages. The last thing to arrive is the
        //    child's own desk — revealing the real world inside the virtual
        //    water is the quiet payoff of this ritual.
        let stages: [(threshold: Double, alpha: Double, yOffset: CGFloat, width: CGFloat)] = [
            (0.15, 0.22, 26, 0.30),
            (0.38, 0.26, 54, 0.44),
            (0.60, 0.30, 86, 0.58),
            (0.82, 0.34, 124, 0.74)
        ]
        for s in stages where c > s.threshold {
            let local = min(1, (c - s.threshold) / 0.18)
            let w = size.width * s.width
            let x = (size.width - w) / 2
            let y = surfaceY + s.yOffset
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addQuadCurve(to: CGPoint(x: x + w, y: y),
                                control: CGPoint(x: x + w / 2, y: y - 7 * local))
            ctx.stroke(streak,
                       with: .color(Color.white.opacity(s.alpha * local)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }

        // ── Mirror-flat highlight when fully cleared.
        if c > 0.94 {
            var line = Path()
            line.move(to: CGPoint(x: size.width * 0.16, y: surfaceY + 1))
            line.addLine(to: CGPoint(x: size.width * 0.84, y: surfaceY + 1))
            ctx.stroke(line, with: .color(Color.white.opacity(0.40)), lineWidth: 1.4)
        }

        // ── The egg rises as the water clears. It is never announced.
        if c > 0.45 {
            let rise = min(1, (c - 0.45) / 0.55)
            let r = size.width * 0.055
            let cx = size.width * 0.5
            let cy = surfaceY + 60 - CGFloat(rise) * 34
            var egg = Path()
            egg.addEllipse(in: CGRect(x: cx - r * 0.82, y: cy - r, width: r * 1.64, height: r * 2))
            ctx.fill(egg, with: .color(colors.bark.mixed(with: colors.pollen, 0.22)
                .opacity(0.25 + 0.70 * rise)))
            // A hairline crack appears at the very end.
            if rise > 0.90 {
                var crack = Path()
                crack.move(to: CGPoint(x: cx - r * 0.5, y: cy - r * 0.15))
                crack.addLine(to: CGPoint(x: cx - r * 0.05, y: cy + r * 0.10))
                crack.addLine(to: CGPoint(x: cx + r * 0.42, y: cy - r * 0.22))
                ctx.stroke(crack, with: .color(colors.soilDeep.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            // Reflection of the egg in the clearing water.
            if !reduceMotion, c > 0.7 {
                var ref = Path()
                ref.addEllipse(in: CGRect(x: cx - r * 0.7, y: cy + r * 1.1,
                                          width: r * 1.4, height: r * 0.9))
                ctx.fill(ref, with: .color(colors.bark.opacity(0.10 * (c - 0.7) / 0.3)))
            }
        }
    }
}
