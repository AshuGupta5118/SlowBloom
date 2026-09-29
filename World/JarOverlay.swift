import SwiftUI

/// The glass itself, drawn ABOVE the world.
///
/// This is the diegetic heart of the design language: the chrome of this app
/// is not glass styled onto the interface, it IS the jar. So the negative
/// state is not an overlay — it is condensation forming on the inside of this
/// same glass, and it clears when the child breathes.
struct JarOverlay: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityIncreasedContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let layout = JarLayout.make(in: proxy.size)
            let jar = layout.jar
            let shape = JarShape().path(in: jar)
            let fog = state.engine.fogLevel
            let colors = resolvedColors

            ZStack {
                // ── Glass body
                shape.fill(.linearGradient(
                    Gradient(stops: [
                        .init(color: Color.white.opacity(scheme == .dark ? 0.16 : 0.22), location: 0),
                        .init(color: Color.white.opacity(0.05), location: 0.38),
                        .init(color: Color.white.opacity(0.02), location: 0.72),
                        .init(color: Color.white.opacity(scheme == .dark ? 0.13 : 0.17), location: 1)
                    ]),
                    startPoint: CGPoint(x: jar.minX, y: jar.minY),
                    endPoint: CGPoint(x: jar.maxX, y: jar.maxY)))

                // ── Fog: tint + frost texture. Two channels, never colour alone.
                if fog > 0.02 {
                    shape.fill(colors.sleepy.opacity(fog * 0.34))
                    FrostTexture(fog: fog, rect: jar)
                        .clipShape(JarShape().path(in: jar).asShape())
                }

                // ── Specular highlight. ONE soft highlight per surface.
                HighlightPath(rect: jar)
                    .fill(Color.white.opacity(scheme == .dark ? 0.13 : 0.20))
                EdgeGlint(rect: jar)
                    .stroke(Color.white.opacity(0.10),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // ── Rim: the brass fitting
                RimPath(rect: jar)
                    .stroke(colors.pollen.mixed(with: Color.white, 0.25).opacity(0.50),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // ── Edge
                shape.stroke(colors.glassEdge, lineWidth: 1.6)
            }
            .animation(BloomMotion.sleepy(state.motionScale), value: Int(fog * 12))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var resolvedColors: WorldColors {
        var c = WorldColors.make(dark: scheme == .dark, highContrast: contrast)
        if state.goldenHour { c = c.goldenHour() }
        return c
    }
}

// MARK: - Frost texture
/// The Differentiate Without Color channel for the sleepy state: fog adds a
/// visible TEXTURE, so it survives greyscale and Increased Contrast.
private struct FrostTexture: View {
    let fog: Double
    let rect: CGRect

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { _ in
            Canvas { ctx, _ in
                var rng = SeededRNG(seed: 0xF405_71CE)
                let count = Int(90.0 * min(1, fog))
                guard count > 0 else { return }
                for _ in 0..<count {
                    let x = rect.minX + CGFloat(rng.unit()) * rect.width
                    let y = rect.minY + CGFloat(rng.unit()) * rect.height
                    let r = CGFloat(rng.range(0.8, 3.0)) * CGFloat(0.5 + fog * 0.7)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)),
                             with: .color(Color.white.opacity(0.10 + 0.16 * fog)))
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
    }
}

// MARK: - Condensation
/// Droplets on the INSIDE of the glass. Each has its own size-driven speed.
///
/// When fog falls they shrink and drift back UP, re-absorbing. That is
/// physically wrong and emotionally perfect: it reads as the glass healing.
/// Children never question it.
struct Condensation: View {
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { proxy in
            let layout = JarLayout.make(in: proxy.size)
            let fog = state.engine.fogLevel
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                Canvas { ctx, _ in
                    guard fog > 0.04 else { return }
                    let jar = layout.jar
                    let time = tl.date.timeIntervalSinceReferenceDate
                    var rng = SeededRNG(seed: 0xC0DE_3A5E)
                    for _ in 0..<26 {
                        let bx = rng.range(0.06, 0.94)
                        let by = rng.range(0.10, 0.72)
                        let size = rng.range(3.0, 9.0)
                        let speed = rng.range(0.10, 0.34) * (size / 9.0)
                        let wobble = sin(time * 0.6 + bx * 9) * 0.006
                        // Slide distance grows with fog; reversing fog lifts them.
                        let slide = CGFloat(fog * speed) * jar.height * 0.55
                        let x = jar.minX + CGFloat(bx + wobble) * jar.width
                        let y = jar.minY + CGFloat(by) * jar.height + slide
                        let r = size * CGFloat(0.45 + 0.55 * fog)
                        let alpha = min(1, max(0, (fog - 0.04) / 0.28)) * 0.52
                        var drop = Path()
                        drop.addEllipse(in: CGRect(x: x - r / 2, y: y - r * 0.68,
                                                   width: r, height: r * 1.36))
                        ctx.fill(drop, with: .color(Color.white.opacity(alpha)))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.22, y: y - r * 0.42,
                                                        width: r * 0.30, height: r * 0.34)),
                                 with: .color(Color.white.opacity(alpha * 0.9)))
                    }
                }
                .clipShape(JarShape().path(in: layout.jar).asShape())
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Shapes

private struct HighlightPath: Shape {
    let rect: CGRect
    func path(in r: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.055
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + rect.height * 0.30))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset * 1.5, y: rect.minY + rect.height * 0.09),
                       control: CGPoint(x: rect.minX + inset * 0.9, y: rect.minY + rect.height * 0.18))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + inset * 0.7),
                       control: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + inset * 0.6))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset * 1.1, y: rect.minY + rect.height * 0.62),
                       control: CGPoint(x: rect.minX + inset * 0.5, y: rect.minY + rect.height * 0.34))
        p.closeSubpath()
        return p
    }
}

private struct EdgeGlint: Shape {
    let rect: CGRect
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.045, y: rect.minY + rect.height * 0.16))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.038, y: rect.minY + rect.height * 0.62),
                       control: CGPoint(x: rect.maxX - rect.width * 0.020, y: rect.minY + rect.height * 0.40))
        return p
    }
}

private struct RimPath: Shape {
    let rect: CGRect
    func path(in r: CGRect) -> Path {
        var p = Path()
        let corner = min(rect.width, rect.height) * 0.155
        p.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + corner * 1.05))
        p.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.minY + 2),
                       control: CGPoint(x: rect.minX + 4, y: rect.minY + corner * 0.35))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.minY + corner * 1.05),
                       control: CGPoint(x: rect.maxX - 4, y: rect.minY + corner * 0.35))
        return p
    }
}

// MARK: - Path -> Shape bridge
/// `clipShape` wants a Shape; we already have the jar as a Path.
extension Path {
    func asShape() -> some Shape {
        PathShape(path: self)
    }
}
struct PathShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}
