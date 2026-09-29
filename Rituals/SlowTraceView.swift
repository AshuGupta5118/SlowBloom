import SwiftUI

/// One point of the trace, with the instantaneous speed at which it was made.
struct TraceSample {
    let point: CGPoint
    let time: TimeInterval
    let speed: Double      // pt/s
}

/// RITUAL A — Slow Trace.
///
/// A pollen spark drifts along the vine at exactly the target pace. The
/// child's only job is to follow it, which works for a pre-reader and needs no
/// numbers. Where they rush, the stroke renders THINNER AND PALER — like a pen
/// running out of ink. Instant, wordless, and never a failure state: lifting
/// the finger costs time, never progress.
///
/// On completion the trace's deliberateness seeds `PlantGenome`, so the flower
/// that blooms is a portrait of how this child actually moved.
struct SlowTraceView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let namespace: Namespace.ID

    @State private var vine: VinePath?
    @State private var samples: [TraceSample] = []
    /// Speed bucketed by position along the vine, so the rendered width can be
    /// looked up by fraction without the two arrays drifting out of step.
    @State private var speedBuckets: [Double] = Array(repeating: 0, count: 128)
    @State private var lastPoint: CGPoint?
    @State private var lastTime: TimeInterval?
    @State private var smoothedSpeed: Double = 0
    @State private var progress: Double = 0
    @State private var lifts: Int = 0
    @State private var completed = false
    @State private var dwellMode = false
    @State private var dwellLength: Double = 0
    @State private var dwellTarget: CGPoint = .zero

    var body: some View {
        GeometryReader { proxy in
            let rect = Self.vineRect(in: proxy.size)
            let path = vine ?? VinePath.make(in: rect, seed: 0x57AC_E001, complexity: 4)

            ZStack {
                RitualBackdrop()

                // Captured as plain values: a Canvas renderer closure is not
                // MainActor-isolated, so it must never touch observable state.
                let guide = state.traceGuide
                let size = proxy.size

                TimelineView(.animation) { timeline in
                    Canvas { ctx, _ in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        if dwellMode {
                            drawDwell(&ctx, size: size, time: time)
                        } else {
                            drawVine(&ctx, path: path, time: time, guide: guide)
                        }
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(traceGesture(path: path))

                chrome()
            }
            .onAppear { if vine == nil { vine = VinePath.make(in: rect, seed: 0x57AC_E001, complexity: 4) } }
        }
        .onDisappear { state.engine.input = .idle }
    }

    static func vineRect(in size: CGSize) -> CGRect {
        CGRect(x: size.width * 0.09, y: size.height * 0.30,
               width: size.width * 0.82, height: size.height * 0.40)
    }

    // MARK: - Chrome

    @ViewBuilder
    private func chrome() -> some View {
        VStack {
            HStack(alignment: .top) {
                Button {
                    state.endRitual(completed: false)
                } label: {
                    Image(systemName: BloomSymbol.close)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 46, height: 46)
                        .bloomGlass(.fitting, shape: BloomShape.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave the ritual")
                .accessibilityHint("Returns to the garden. Nothing is lost.")

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    metric(BloomCopy.traceSpeed, "\(Int(smoothedSpeed.rounded()))", "pt/s")
                    metric(BloomCopy.traceLifts, "\(lifts)", nil)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            PromptBanner(text: dwellMode ? BloomCopy.stillHint : BloomCopy.traceTitle)
                .matchedGeometryEffect(id: "hud-prompt", in: namespace, isSource: true)
                .padding(.bottom, 10)

            HStack(spacing: 14) {
                Button {
                    withAnimation(BloomMotion.morph(state.motionScale)) {
                        dwellMode.toggle()
                        reset()
                    }
                } label: {
                    Text(BloomCopy.traceDwell)
                        .font(.bloomCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(dwellMode ? Color.primary : Color.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .bloomGlass(.fitting, shape: BloomShape.pill,
                                    tint: dwellMode
                                        ? Color(red: 0.56, green: 0.75, blue: 0.42).opacity(0.32)
                                        : nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hold instead of drawing")
                .accessibilityHint("Grows a vine toward your finger, with no tracing")

                Text(BloomCopy.traceNoTimer)
                    .font(.bloomCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 26)
        }
    }

    private func metric(_ label: String, _ value: String, _ unit: String?) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label).font(.bloomCaption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.bloomMetricBig)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)
                if let unit {
                    Text(unit).font(.bloomCaption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .bloomGlass(.wall, shape: BloomShape.panel(16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) \(unit ?? "")")
    }

    // MARK: - Gesture

    @MainActor
    private func traceGesture(path: VinePath) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !completed else { return }
                let now = Date().timeIntervalSinceReferenceDate
                state.engine.input.isTouching = true
                let dt = min(0.1, max(0, now - (lastTime ?? now)))
                lastTime = now

                // ── Dwell Mode: same reward, no fine motor control required.
                if dwellMode {
                    dwellTarget = value.location
                    let rate = 0.16 + 0.40 * state.engine.calm
                    dwellLength = min(1, dwellLength + dt * rate)
                    let d = min(1, 0.35 + state.engine.calm * 0.60)
                    state.ritualDeliberateness = d
                    state.engine.input.traceDeliberateness = d
                    if dwellLength >= 1 { finish() }
                    return
                }

                // ── Trace
                if let lp = lastPoint {
                    let dist = hypot(value.location.x - lp.x, value.location.y - lp.y)
                    let inst = dt > 1e-4 ? dist / dt : 0
                    smoothedSpeed = smoothedSpeed * 0.72 + inst * 0.28
                    samples.append(TraceSample(point: value.location, time: now, speed: inst))
                } else {
                    samples.append(TraceSample(point: value.location, time: now, speed: 0))
                }
                lastPoint = value.location
                state.engine.input.pointerSpeed = smoothedSpeed
                state.engine.input.liftCount = lifts

                credit(path: path, at: value.location)
                let d = deliberateness()
                state.ritualDeliberateness = d
                state.engine.input.traceDeliberateness = d
            }
            .onEnded { _ in
                state.engine.input.isTouching = false
                state.engine.input.pointerSpeed = 0
                smoothedSpeed = 0
                lastPoint = nil
                guard !completed else { return }
                if !dwellMode, samples.count > 3 {
                    lifts += 1
                    state.ritualLifts = lifts
                }
            }
    }

    /// Progress is credited only when the finger is genuinely ON the vine, and
    /// only when it doesn't jump ahead. No skipping to the end.
    private func credit(path: VinePath, at p: CGPoint) {
        guard path.line.distance(nearest: p) < 52 else { return }
        let f = path.line.fraction(nearest: p)
        guard f > progress, (f - progress) < 0.09 else { return }
        progress = f
        let bucket = min(speedBuckets.count - 1, Int(f * Double(speedBuckets.count)))
        speedBuckets[bucket] = smoothedSpeed
        if progress >= 0.93 { finish() }
    }

    @MainActor
    private func finish() {
        guard !completed else { return }
        completed = true
        state.ritualDeliberateness = deliberateness()
        state.ritualLifts = lifts
        state.endRitual(completed: true)
    }

    private func reset() {
        samples.removeAll()
        speedBuckets = Array(repeating: 0, count: 128)
        progress = 0
        lifts = 0
        dwellLength = 0
        completed = false
        smoothedSpeed = 0
        lastPoint = nil
        lastTime = nil
        state.ritualLifts = 0
    }

    // MARK: - Metrics

    /// deliberateness = slow enough + steady + continuous + engaged.
    /// Step 1 has no pressure data, so `engaged` is a neutral 0.5. Step 2
    /// restores the Apple Pencil term and reweights to the full formula.
    private func deliberateness() -> Double {
        let recent = Array(samples.suffix(90)).map(\.speed).filter { $0 > 1 }
        guard recent.count > 5 else { return 0.5 }
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recent.count)
        let cv = mean > 1 ? sqrt(variance) / mean : 0

        let slowEnough = 1 - min(1, max(0, mean / 900))
        let steady     = 1 - min(1, max(0, cv / 0.9))
        let continuous = lifts == 0 ? 1.0 : max(0, 1 - 0.30 * Double(lifts))
        let engaged    = 0.5
        return 0.35 * slowEnough + 0.30 * steady + 0.25 * continuous + 0.10 * engaged
    }

    // MARK: - Drawing

    private func drawVine(_ ctx: inout GraphicsContext, path: VinePath, time: Double, guide: Double) {
        let colors = WorldColors.make(dark: scheme == .dark)
        let pts = path.line.points
        guard pts.count > 2 else { return }

        var ghost = Path()
        ghost.addLines(pts)
        ctx.stroke(ghost, with: .color(colors.fern.opacity(0.20)),
                   style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
        ctx.stroke(ghost, with: .color(colors.moss.opacity(0.09)),
                   style: StrokeStyle(lineWidth: 46, lineCap: .round, lineJoin: .round))

        // Traced portion. Width comes from the speed bucket at that fraction,
        // so rushing produces a visibly thinner, paler line.
        let n = max(1, Int(Double(pts.count - 1) * min(1, progress)))
        guard n >= 2 else { return }
        let traced = Array(pts[0...n])
        let tracedPath = PlantGeometry.taperedPath(traced) { t in
            let frac = t * CGFloat(min(1, progress))
            let bucket = min(speedBuckets.count - 1, Int(frac * Double(speedBuckets.count)))
            let sp = speedBuckets[bucket]
            let ratio = sp > 1 ? min(1.7, 210.0 / sp) : 1.0
            return 24.0 * min(1.15, max(0.28, ratio))
        }
        ctx.fill(tracedPath, with: .color(colors.moss.opacity(0.95)))

        // A leaf unfurls every ~15% of the path.
        let leafCount = min(6, Int(progress / 0.15))
        for i in 0..<leafCount {
            let f = Double(i + 1) * 0.15
            guard f <= progress else { continue }
            let origin = path.point(atFraction: f)
            let tan = path.tangent(atFraction: f)
            let side: CGFloat = tan.dy >= 0 ? 1 : -1
            let baseAngle = atan2(tan.dy, tan.dx) + side * 1.05
            let dir = CGVector(dx: cos(baseAngle), dy: sin(baseAngle))
            let perp = CGVector(dx: -sin(baseAngle), dy: cos(baseAngle))
            let map: (CGPoint) -> CGPoint = { p in
                CGPoint(x: origin.x + p.x * dir.dx + p.y * perp.dx,
                        y: origin.y + p.x * dir.dy + p.y * perp.dy)
            }
            ctx.fill(PlantGeometry.leafPath(length: 34, widthFactor: 0.44, map: map),
                     with: .color(colors.fern.opacity(0.92)))
        }

        // The pollen spark: the guide the child follows.
        if !completed {
            let g = min(1, max(guide, progress))
            let c = path.point(atFraction: g)
            if !reduceMotion {
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 16))
                    layer.fill(Path(ellipseIn: CGRect(x: c.x - 26, y: c.y - 26, width: 52, height: 52)),
                               with: .color(colors.pollen.opacity(0.42)))
                }
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)),
                     with: .color(colors.pollen))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9)),
                     with: .color(Color.white.opacity(0.72)))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 18, y: c.y - 18, width: 36, height: 36)),
                       with: .color(colors.pollen.opacity(0.42)), lineWidth: 1.6)
        }
    }

    /// DWELL MODE — the accessibility alternative. Continuous tracing is
    /// impossible for a child with tremors or limited fine motor control, so
    /// this offers the SAME reward for holding still instead of drawing.
    /// Directly inspired by Steady Hands (SSC 2026 Distinguished Winner).
    private func drawDwell(_ ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let colors = WorldColors.make(dark: scheme == .dark)
        let base = CGPoint(x: size.width / 2, y: size.height * 0.86)
        let target = dwellTarget == .zero
            ? CGPoint(x: size.width / 2, y: size.height * 0.28)
            : dwellTarget
        let dx = target.x - base.x, dy = target.y - base.y
        let full = max(1, hypot(dx, dy))
        let len = CGFloat(min(1, dwellLength)) * full
        guard len > 4 else {
            ctx.stroke(Path(ellipseIn: CGRect(x: base.x - 30, y: base.y - 30, width: 60, height: 60)),
                       with: .color(colors.pollen.opacity(0.35)), lineWidth: 2)
            return
        }

        var pts: [CGPoint] = []
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            if t * full > len { break }
            let bow = CGFloat(sin(Double(t) * .pi) * 26 * (1 - Double(t)))
            pts.append(CGPoint(x: base.x + dx * t - dy / full * bow,
                               y: base.y + dy * t + dx / full * bow))
        }
        guard pts.count >= 2 else { return }
        ctx.fill(PlantGeometry.taperedPath(pts) { t in 18 * (1 - 0.7 * t) },
                 with: .color(colors.moss.opacity(0.95)))

        for i in 0..<min(5, pts.count / 5) {
            let idx = min(pts.count - 1, (i + 1) * 4)
            let o = pts[idx]
            let side: CGFloat = i % 2 == 0 ? 1 : -1
            let a = atan2(dy, dx) + side * 1.0
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let perp = CGVector(dx: -sin(a), dy: cos(a))
            let map: (CGPoint) -> CGPoint = { p in
                CGPoint(x: o.x + p.x * dir.dx + p.y * perp.dx,
                        y: o.y + p.x * dir.dy + p.y * perp.dy)
            }
            ctx.fill(PlantGeometry.leafPath(length: 30, widthFactor: 0.44, map: map),
                     with: .color(colors.fern.opacity(0.90)))
        }

        let tip = pts[pts.count - 1]
        ctx.stroke(Path(ellipseIn: CGRect(x: tip.x - 26, y: tip.y - 26, width: 52, height: 52)),
                   with: .color(colors.pollen.opacity(0.5)), lineWidth: 2)
        if !reduceMotion {
            let pulse = 1 + 0.06 * sin(time * 2.2)
            ctx.stroke(Path(ellipseIn: CGRect(x: tip.x - 34 * pulse, y: tip.y - 34 * pulse,
                                              width: 68 * pulse, height: 68 * pulse)),
                       with: .color(colors.pollen.opacity(0.20)), lineWidth: 1.4)
        }
    }
}

/// Shared ritual backdrop. Dark, calm, no decoration.
struct RitualBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(colors: scheme == .dark
            ? [Color(red: 0.100, green: 0.125, blue: 0.095),
               Color(red: 0.050, green: 0.065, blue: 0.050)]
            : [Color(red: 0.900, green: 0.930, blue: 0.880),
               Color(red: 0.820, green: 0.860, blue: 0.810)],
            startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
}
