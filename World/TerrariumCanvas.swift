import SwiftUI

// MARK: - Layout

/// Everything the world needs to know about where things are, derived once
/// per frame from the view size. The jar occupies the centre 60% — content
/// first, chrome recedes.
struct JarLayout {
    var jar: CGRect
    var soilTop: CGFloat
    var waterRect: CGRect
    var floorY: CGFloat

    static func make(in size: CGSize) -> JarLayout {
        let w = min(size.width * 0.66, 560)
        let h = min(size.height * 0.70, w * 1.18)
        let jar = CGRect(x: (size.width - w) / 2,
                         y: (size.height - h) / 2 - size.height * 0.02,
                         width: w, height: h)
        let soilTop = jar.maxY - jar.height * 0.20
        return JarLayout(jar: jar,
                         soilTop: soilTop,
                         waterRect: CGRect(x: jar.minX + jar.width * 0.10,
                                           y: soilTop + jar.height * 0.045,
                                           width: jar.width * 0.80,
                                           height: jar.height * 0.115),
                         floorY: soilTop + 6)
    }

    /// Where a plant rooted at normalised x sits.
    func rootPoint(forX nx: CGFloat) -> CGPoint {
        CGPoint(x: jar.minX + nx * jar.width, y: floorY)
    }
}

/// The jar silhouette. Shared by the clip, the world canvas and the glass
/// overlay so all three always agree.
struct JarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.155
        return Path(roundedRect: rect, cornerRadius: r, style: .continuous)
    }
}

/// A plant paired with its precomputed structure, so the Canvas closure only
/// ever touches plain values.
struct PlantRenderEntry {
    let plant: Plant
    let structure: PlantStructure
}

// MARK: - Structure cache

/// Catmull-Rom resampling is not free. Structures are pure functions of
/// (genome, species), so cache them — the genome never changes once planted.
@MainActor
final class PlantStructureCache {
    static let shared = PlantStructureCache()
    private struct Key: Hashable { let species: String; let genome: PlantGenome }
    private var cache: [Key: PlantStructure] = [:]

    func structure(genome: PlantGenome, species: Species) -> PlantStructure {
        let k = Key(species: species.id, genome: genome)
        if let hit = cache[k] { return hit }
        let s = PlantGeometry.structure(genome: genome, species: species)
        cache[k] = s
        return s
    }
    func purge() { cache.removeAll() }
}

// MARK: - The world

/// ONE TimelineView drives the entire world. Nothing here is keyframed:
/// growth, droop, sway, ripples and breathing are all continuous functions of
/// `calm`, `wind` and `time`. That is what makes it feel alive rather than
/// animated — the child can SEE growth pause when they fidget.
struct TerrariumCanvas: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityIncreasedContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // ── Everything the Canvas needs is resolved HERE, in the MainActor
        //    view body, and captured as plain values. A Canvas renderer closure
        //    is NOT MainActor-isolated, so touching observable state inside one
        //    is an isolation error. This split is the whole trick.
        let colors = resolvedColors
        let particles = state.profile.particlesEnabled(reduceMotion: reduceMotion)
        let wind = state.engine.wind
        let calm = state.engine.calm
        let creatures = state.garden.garden.creatures
        let entries: [PlantRenderEntry] = state.garden.garden.plants
            .sorted { $0.position.x < $1.position.x }   // back-to-front
            .map { plant in
                PlantRenderEntry(
                    plant: plant,
                    structure: PlantStructureCache.shared.structure(genome: plant.genome,
                                                                    species: plant.species))
            }
        let isDark = (scheme == .dark)

        TimelineView(.animation) { timeline in
            Canvas(rendersAsynchronously: false) { ctx, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let layout = JarLayout.make(in: size)

                ctx.clip(to: JarShape().path(in: layout.jar))
                drawInteriorBackground(&ctx, layout: layout, colors: colors, dark: isDark)
                drawSoil(&ctx, layout: layout, colors: colors)
                drawWater(&ctx, layout: layout, colors: colors,
                          wind: wind, calm: calm, time: time)

                for entry in entries {
                    drawPlant(&ctx, entry: entry, layout: layout, colors: colors,
                              time: time, wind: wind, particles: particles)
                }
                for creature in creatures {
                    drawCreature(&ctx, creature: creature, layout: layout,
                                 colors: colors, time: time)
                }
                if particles {
                    drawPollen(&ctx, layout: layout, colors: colors, time: time, calm: calm)
                }
            }
        }
        .accessibilityHidden(true)     // the world is narrated by TerrariumScreen
    }

    private var resolvedColors: WorldColors {
        var c = WorldColors.make(dark: scheme == .dark, highContrast: contrast)
        if state.goldenHour { c = c.goldenHour() }
        return c
    }

    // MARK: Background / soil / water

    private func drawInteriorBackground(_ ctx: inout GraphicsContext,
                                        layout: JarLayout, colors: WorldColors,
                                        dark: Bool) {
        let g = Gradient(colors: [
            colors.dusk.opacity(dark ? 0.20 : 0.12),
            Color.black.opacity(dark ? 0.42 : 0.10)
        ])
        ctx.fill(Path(layout.jar),
                 with: .linearGradient(g,
                                       startPoint: CGPoint(x: layout.jar.midX, y: layout.jar.minY),
                                       endPoint: CGPoint(x: layout.jar.midX, y: layout.jar.maxY)))
    }

    private func drawSoil(_ ctx: inout GraphicsContext, layout: JarLayout, colors: WorldColors) {
        var body = Path()
        let r = layout.jar
        body.move(to: CGPoint(x: r.minX, y: layout.soilTop + 8))
        body.addQuadCurve(to: CGPoint(x: r.midX, y: layout.soilTop - 4),
                          control: CGPoint(x: r.minX + r.width * 0.28, y: layout.soilTop - 2))
        body.addQuadCurve(to: CGPoint(x: r.maxX, y: layout.soilTop + 8),
                          control: CGPoint(x: r.minX + r.width * 0.72, y: layout.soilTop - 6))
        body.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        body.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        body.closeSubpath()
        ctx.fill(body, with: .linearGradient(
            Gradient(colors: [colors.soil, colors.soilDeep]),
            startPoint: CGPoint(x: r.midX, y: layout.soilTop),
            endPoint: CGPoint(x: r.midX, y: r.maxY)))
        // A lighter crust catches the light.
        ctx.stroke(body, with: .color(colors.soil.opacity(0.55)), lineWidth: 2)
    }

    private func drawWater(_ ctx: inout GraphicsContext, layout: JarLayout,
                           colors: WorldColors, wind: Double, calm: Double,
                           time: Double) {
        let wr = layout.waterRect
        // Amplitude damps as calm accumulates. The water settling IS the
        // progress bar for Still Water — never a number, never a countdown.
        let amp = CGFloat(wind * 0.045 + 0.004) * wr.height
        var top = Path()
        let steps = 26
        top.move(to: CGPoint(x: wr.minX, y: wr.midY))
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let x = wr.minX + f * wr.width
            let y = wr.midY + sin(Double(f) * 7.0 + time * 1.7) * Double(amp)
                            + sin(Double(f) * 3.1 - time * 1.1) * Double(amp) * 0.5
            top.addLine(to: CGPoint(x: x, y: y))
        }
        top.addLine(to: CGPoint(x: wr.maxX, y: wr.maxY))
        top.addLine(to: CGPoint(x: wr.minX, y: wr.maxY))
        top.closeSubpath()

        ctx.fill(top, with: .linearGradient(
            Gradient(colors: [colors.water.opacity(0.62), colors.water.opacity(0.22)]),
            startPoint: CGPoint(x: wr.midX, y: wr.minY),
            endPoint: CGPoint(x: wr.midX, y: wr.maxY)))

        // Reflections appear only as the water clears — and the last thing to
        // show up is the child's own desk. Revealing the real world inside the
        // virtual water is the quiet payoff of this ritual.
        let clarity = min(1, max(0, (calm - 0.55) / 0.45))
        if clarity > 0.02 {
            for i in 0..<3 {
                let f = CGFloat(i) / 2.0
                let x = wr.minX + wr.width * (0.26 + 0.24 * f)
                var streak = Path()
                streak.move(to: CGPoint(x: x, y: wr.midY + 3))
                streak.addQuadCurve(to: CGPoint(x: x + wr.width * 0.12, y: wr.midY + 5),
                                    control: CGPoint(x: x + wr.width * 0.06, y: wr.midY - 2))
                ctx.stroke(streak,
                           with: .color(Color.white.opacity(0.34 * clarity)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
    }

    // MARK: Plants

    private func drawPlant(_ ctx: inout GraphicsContext, entry: PlantRenderEntry,
                           layout: JarLayout, colors: WorldColors,
                           time: Double, wind: Double, particles: Bool) {
        let plant = entry.plant
        let species = plant.species
        guard species.kind != .creature else { return }
        let s = entry.structure

        let maturity = plant.maturity
        let height = layout.jar.height * s.heightFactor * CGFloat(0.28 + 0.72 * maturity)
        guard height > 3 else { return }

        // Droop from sleepiness (fast in, slow out — handled in the store),
        // sway from wind. Reduce Motion removes the sway, never the droop:
        // droop is information, sway is decoration.
        let droop = plant.sleepiness * 9.0
        let swayAmp = reduceMotion ? 0.15 : (0.7 + wind * 10.0)
        let phase = Double(GardenStore.fnv1a(plant.id.uuidString) % 1000) / 160.0
        let sway = sin(time * 1.05 + phase) * swayAmp
        let lean = (plant.position.x < 0.5 ? 1.0 : -1.0)   // lean toward the glass

        let placement = PlantPlacement(
            base: layout.rootPoint(forX: plant.position.x),
            height: height,
            rotation: CGFloat((droop * lean + sway) * .pi / 180.0))

        let sleepy = plant.sleepiness
        let stemColor = colors.fern
            .mixed(with: colors.moss, 0.45)
            .desaturated(sleepy * 0.55)
        let leafColorA = colors.moss.desaturated(sleepy * 0.55)
        let leafColorB = colors.fern.desaturated(sleepy * 0.55)

        // ── Stem, drawn only as far as growth has reached.
        let grown = s.stem.prefix(0.10 + 0.90 * maturity)
        let stemPts = grown.points.map { placement.map($0) }
        let baseW = s.stemWidth * height
        let stemPath = PlantGeometry.taperedPath(stemPts) { t in
            baseW * (1.0 - 0.74 * t)
        }
        ctx.fill(stemPath, with: .color(stemColor))

        // ── Leaves unfurl progressively up the stem.
        for (i, leaf) in s.leaves.enumerated() {
            let unfurl = min(1, max(0, (maturity - leaf.along * 0.62) / 0.30))
            guard unfurl > 0.03 else { continue }

            let originUnit = s.stem.point(at: leaf.along)
            let tangentUnit = s.stem.tangent(at: leaf.along)
            let origin = placement.map(originUnit)
            let tan = placement.rotated(CGVector(dx: tangentUnit.dx * 0.62,
                                                 dy: -tangentUnit.dy))
            // Leaf direction = stem tangent rotated outward by `tilt`,
            // plus its own droop response.
            let extra = leaf.tilt + (sleepy * 0.30 * leaf.droopGain)
                        + sin(time * 0.9 + phase + Double(i)) * (reduceMotion ? 0.0 : 0.05 + wind * 0.22)
            let baseAngle = atan2(tan.dy, tan.dx)
            let angle = baseAngle + CGFloat(extra) * leaf.side
            let dir = CGVector(dx: cos(angle), dy: sin(angle))
            let perp = CGVector(dx: -sin(angle), dy: cos(angle))

            let L = placement.len(CGFloat(leaf.length)) * CGFloat(unfurl)
            guard L > 1.5 else { continue }
            let map: (CGPoint) -> CGPoint = { p in
                CGPoint(x: origin.x + p.x * dir.dx + p.y * perp.dx,
                        y: origin.y + p.x * dir.dy + p.y * perp.dy)
            }
            let body = PlantGeometry.leafPath(length: L,
                                              widthFactor: CGFloat(leaf.widthFactor),
                                              map: map)
            let c = leafColorA.mixed(with: leafColorB, (leaf.hueBias + 1) / 2)
            ctx.fill(body, with: .color(c.opacity(0.94)))
            // Two-tone per organ: a lighter upper half. Real leaves are never
            // one flat colour.
            ctx.drawLayer { layer in
                layer.clip(to: body)
                layer.opacity = 0.22
                layer.fill(body.applying(CGAffineTransform(translationX: 0, y: -L * 0.08)),
                           with: .color(colors.pollen))
            }
            ctx.stroke(PlantGeometry.leafMidrib(length: L, map: map),
                       with: .color(stemColor.opacity(0.5)),
                       style: StrokeStyle(lineWidth: max(0.7, L * 0.022), lineCap: .round))
        }

        // ── Flower. Opens only in the last 45% of maturity.
        guard let f = s.flower else { return }
        let open = min(1, max(0, (maturity - 0.55) / 0.45))
        guard open > 0.02 else { return }

        let centreUnit = s.stem.point(at: min(1, f.along))
        let centre = placement.map(centreUnit)
        let petalR = placement.len(CGFloat(f.size)) * CGFloat(open)
        guard petalR > 2 else { return }

        let hue = (species.hue + f.hueShift).truncatingRemainder(dividingBy: 1)
        let petalBase = Color(hue: max(0, min(1, hue)),
                              saturation: 0.34 + 0.16 * f.sss,
                              brightness: 0.94)
        let petalColor = petalBase.desaturated(sleepy * 0.6)

        for i in 0..<max(3, f.petalCount) {
            // Petals at the golden angle, not evenly spaced. That is why it
            // reads as a flower rather than a pinwheel.
            let a = Double(i) * PlantGeometry.goldenAngle
            // Stagger: outer petals lead, 0.045s apart in feel.
            let po = min(1, max(0, open - Double(i) * 0.055))
            guard po > 0.02 else { continue }
            let len = petalR * CGFloat(po) * (1.0 - 0.10 * CGFloat(i % 3))
            let wid = len * 0.40
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let perp = CGVector(dx: -sin(a), dy: cos(a))
            let map: (CGPoint) -> CGPoint = { p in
                CGPoint(x: centre.x + p.x * dir.dx + p.y * perp.dx,
                        y: centre.y + p.x * dir.dy + p.y * perp.dy)
            }
            let petal = PlantGeometry.leafPath(length: len, widthFactor: 0.40, map: map)
            ctx.fill(petal, with: .color(petalColor.opacity(0.93)))
            // Subsurface: a warm inner glow at the petal base.
            ctx.drawLayer { layer in
                layer.clip(to: petal)
                layer.opacity = 0.16 + 0.30 * f.sss * po
                layer.fill(Path(ellipseIn: CGRect(x: centre.x - wid, y: centre.y - wid,
                                                  width: wid * 2, height: wid * 2)),
                           with: .color(colors.pollen))
            }
        }

        // Disc floret.
        let cr = petalR * 0.30
        ctx.fill(Path(ellipseIn: CGRect(x: centre.x - cr, y: centre.y - cr,
                                        width: cr * 2, height: cr * 2)),
                 with: .color(colors.pollen.desaturated(sleepy * 0.5)))
        ctx.fill(Path(ellipseIn: CGRect(x: centre.x - cr * 0.55, y: centre.y - cr * 0.62,
                                        width: cr * 1.1, height: cr * 1.1)),
                 with: .color(Color.white.opacity(0.22)))

        // Halo, only when particles are allowed.
        if particles {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: petalR * 0.55))
                layer.opacity = 0.30 * (1 - sleepy)
                layer.fill(Path(ellipseIn: CGRect(x: centre.x - petalR, y: centre.y - petalR,
                                                  width: petalR * 2, height: petalR * 2)),
                           with: .color(petalBase))
            }
        }
    }

    // MARK: Creature

    /// Two dots and no mouth. A mouth makes a character; two dots make a
    /// presence. It blinks on a Poisson-ish interval and breathes on a 3.2s
    /// sine — those two idle loops are what turn a shape into a creature.
    private func drawCreature(_ ctx: inout GraphicsContext, creature: Creature,
                              layout: JarLayout, colors: WorldColors, time: Double) {
        let phase = Double(GardenStore.fnv1a(creature.id.uuidString) % 997) / 150.0
        let size = layout.jar.width * 0.115 * (0.85 + 0.25 * creature.approach)
        let breathe = reduceMotion ? 1.0 : (1.0 + 0.015 * sin(time * (2 * .pi / 3.2) + phase))
        let s = size * breathe

        // Approaches the glass only after sustained calm; retreats on wind,
        // and ALWAYS returns. Nothing is ever lost.
        let x = layout.jar.minX + creature.position.x * layout.jar.width
        let y = layout.floorY + size * 0.30 - CGFloat(creature.approach) * size * 0.22
        let centre = CGPoint(x: x, y: y)

        var shadow = Path()
        shadow.addEllipse(in: CGRect(x: centre.x - s * 0.55, y: centre.y + s * 0.30,
                                     width: s * 1.1, height: s * 0.22))
        ctx.fill(shadow, with: .color(Color.black.opacity(0.28)))

        let body = colors.bark
        // Ears
        for side in [-1.0, 1.0] {
            let ew = s * 0.26, eh = s * 0.40
            let ex = centre.x + CGFloat(side) * s * 0.30 - ew / 2
            let ey = centre.y - s * 0.62
            var ear = Path()
            ear.addEllipse(in: CGRect(x: ex, y: ey, width: ew, height: eh))
            var t = CGAffineTransform(translationX: ex + ew / 2, y: ey + eh)
            t = t.rotated(by: CGFloat(side * 0.42))
            t = t.translatedBy(x: -(ex + ew / 2), y: -(ey + eh))
            ctx.fill(ear.applying(t), with: .color(body))
        }
        // Body
        var bodyPath = Path()
        bodyPath.addEllipse(in: CGRect(x: centre.x - s * 0.52, y: centre.y - s * 0.46,
                                       width: s * 1.04, height: s * 0.86))
        ctx.fill(bodyPath, with: .color(body))
        // Belly highlight
        ctx.fill(Path(ellipseIn: CGRect(x: centre.x - s * 0.34, y: centre.y - s * 0.10,
                                        width: s * 0.68, height: s * 0.42)),
                 with: .color(body.mixed(with: colors.pollen, 0.35).opacity(0.55)))
        // Eyes — blink
        let bp = (time * 0.26 + phase).truncatingRemainder(dividingBy: 1.0)
        let blink = bp < 0.045 ? max(0.12, 1 - (bp / 0.045)) : 1.0
        let er = s * 0.062
        for side in [-1.0, 1.0] {
            let ex = centre.x + CGFloat(side) * s * 0.17
            let ey = centre.y - s * 0.16
            ctx.fill(Path(ellipseIn: CGRect(x: ex - er, y: ey - er * CGFloat(blink),
                                            width: er * 2, height: er * 2 * CGFloat(blink))),
                     with: .color(Color(red: 0.13, green: 0.10, blue: 0.07)))
            if blink > 0.6 {
                ctx.fill(Path(ellipseIn: CGRect(x: ex - er * 0.4, y: ey - er * 0.9,
                                                width: er * 0.7, height: er * 0.7)),
                         with: .color(Color.white.opacity(0.8)))
            }
        }
    }

    // MARK: Pollen

    private func drawPollen(_ ctx: inout GraphicsContext, layout: JarLayout,
                            colors: WorldColors, time: Double, calm: Double) {
        guard calm > 0.45 else { return }
        var rng = SeededRNG(seed: 0xF011_EE01)
        let n = 16
        for i in 0..<n {
            let sx = rng.range(0.14, 0.86)
            let speed = rng.range(0.018, 0.05)
            let drift = rng.range(-0.05, 0.05)
            let size = rng.range(1.4, 3.2)
            let life = (time * speed + Double(i) / Double(n)).truncatingRemainder(dividingBy: 1.0)
            let x = layout.jar.minX + CGFloat(sx + drift * life) * layout.jar.width
            let y = layout.floorY - CGFloat(life) * layout.jar.height * 0.62
            let alpha = sin(life * .pi) * 0.55 * min(1, (calm - 0.45) / 0.35)
            guard alpha > 0.02 else { continue }
            ctx.fill(Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2,
                                            width: size, height: size)),
                     with: .color(colors.pollen.opacity(alpha)))
        }
    }
}
