import CoreGraphics
import Foundation
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic RNG. Same genome must produce the same plant on every frame
// and every relaunch. Never use `String.hashValue` — it is randomised per
// process, so your garden would reshape itself every launch.
// ─────────────────────────────────────────────────────────────────────────────
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {          // splitmix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992.0 }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
}

// MARK: - Polyline with arc-length lookup

struct Polyline {
    let points: [CGPoint]
    private let cumulative: [Double]
    let length: Double

    init(points: [CGPoint]) {
        self.points = points
        var acc: [Double] = [0]
        var total = 0.0
        for i in 1..<max(1, points.count) {
            total += Double(hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y))
            acc.append(total)
        }
        self.cumulative = acc
        self.length = max(1e-6, total)
    }

    /// `d` is 0…1 along the arc length.
    func point(at d: Double) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let target = min(max(d, 0), 1) * length
        var i = 1
        while i < cumulative.count - 1 && cumulative[i] < target { i += 1 }
        let seg = max(1e-6, cumulative[i] - cumulative[i-1])
        let f = CGFloat((target - cumulative[i-1]) / seg)
        let a = points[i-1], b = points[i]
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    func tangent(at d: Double) -> CGVector {
        guard points.count > 1 else { return CGVector(dx: 0, dy: -1) }
        let a = point(at: max(0, d - 0.01)), b = point(at: min(1, d + 0.01))
        let dx = b.x - a.x, dy = b.y - a.y
        let l = max(1e-6, hypot(dx, dy))
        return CGVector(dx: dx / l, dy: dy / l)
    }

    /// The sub-polyline up to `fraction`, resampled. Used for growth.
    func prefix(_ fraction: Double) -> Polyline {
        let f = min(max(fraction, 0), 1)
        guard f > 0.001 else { return Polyline(points: [points[0], points[0]]) }
        let n = max(2, Int(Double(points.count) * f))
        var out: [CGPoint] = []
        for i in 0..<n { out.append(point(at: Double(i) / Double(n - 1) * f)) }
        out.append(point(at: f))
        return Polyline(points: out)
    }
}

// MARK: - Structure

struct LeafPlacement {
    var along: Double        // 0…1 up the stem
    var side: CGFloat        // −1 or +1
    var length: Double       // fraction of plant height
    var widthFactor: Double  // leaf width relative to length
    var tilt: Double         // radians, from the stem tangent
    var droopGain: Double    // how much this leaf reacts to sleepiness
    var hueBias: Double      // −1…1, blends moss↔fern
}

struct FlowerPlacement {
    var along: Double
    var size: Double         // fraction of plant height
    var petalCount: Int
    var hueShift: Double
    var sss: Double
}

struct PlantStructure {
    var stem: Polyline
    var leaves: [LeafPlacement]
    var flower: FlowerPlacement?
    var heightFactor: CGFloat   // plant height as a fraction of jar height
    var stemWidth: CGFloat      // at the base, as a fraction of height
}

// MARK: - Generation

enum PlantGeometry {

    /// 137.507°. Real botany: successive organs at the golden angle produce the
    /// spiral patterns children already recognise from sunflowers and
    /// succulents. One multiplication, and it looks astonishing.
    static let goldenAngle: Double = 137.507 * .pi / 180

    static func structure(genome: PlantGenome, species: Species) -> PlantStructure {
        var rng = SeededRNG(seed: genome.seed ^ GardenStore.fnv1a(species.id))

        let heightFactor: CGFloat
        switch species.kind {
        case .sapling:  heightFactor = 0.52
        case .fern:     heightFactor = 0.34
        case .flower:   heightFactor = 0.42
        case .creature: heightFactor = 0.10
        }

        // ── Stem: a single deterministic lateral bow plus seeded jitter.
        //    No straight lines, ever — every stem is a spline.
        let segments = 5
        var ctrl: [CGPoint] = [CGPoint(x: 0, y: 0)]
        let bow = genome.stemCurvature * rng.range(-0.20, 0.20)
        for i in 1...segments {
            let t = Double(i) / Double(segments)
            let x = bow * sin(t * .pi) + rng.range(-0.018, 0.018)
            ctrl.append(CGPoint(x: x, y: t))
        }
        let stem = Polyline(points: catmullRom(ctrl, samples: 26))

        // ── Leaves at phyllotaxis-derived positions.
        //    cos(i · goldenAngle) gives the natural alternating-but-never-
        //    repeating side pattern. This is why it doesn't look like a ladder.
        let leafCount = species.kind == .flower
            ? max(2, genome.leafCount)
            : max(3, species.frondCount)
        var leaves: [LeafPlacement] = []
        for i in 0..<leafCount {
            let frac = Double(i + 1) / Double(leafCount + 1)
            let along = 0.14 + frac * 0.74
            let a = Double(i) * goldenAngle
            let side: CGFloat = cos(a) >= 0 ? 1 : -1
            // Lower leaves are bigger. Taper everything.
            let len = rng.range(0.20, 0.30) * (1.0 - 0.42 * frac)
            leaves.append(LeafPlacement(
                along: along,
                side: side,
                length: len,
                widthFactor: rng.range(0.34, 0.50) * (0.6 + genome.asymmetry * 0.6),
                tilt: side * rng.range(0.35, 0.85) + rng.range(-0.12, 0.12) * genome.asymmetry,
                droopGain: rng.range(0.7, 1.4),
                hueBias: rng.range(-1, 1)))
        }

        // ── Flower, only for flowering species, only when nearly mature.
        var flower: FlowerPlacement?
        if species.kind == .flower {
            flower = FlowerPlacement(along: 1.0,
                                     size: rng.range(0.16, 0.22) * (0.7 + genome.sssIntensity * 0.5),
                                     petalCount: min(species.maxPetalCount, genome.petalCount),
                                     hueShift: genome.hueShift,
                                     sss: genome.sssIntensity)
        }

        return PlantStructure(stem: stem,
                              leaves: leaves,
                              flower: flower,
                              heightFactor: heightFactor,
                              stemWidth: CGFloat(0.030 + genome.stemCurvature * 0.012))
    }

    /// Standard Catmull-Rom through the control points.
    static func catmullRom(_ p: [CGPoint], samples: Int) -> [CGPoint] {
        guard p.count >= 3 else { return p }
        var out: [CGPoint] = []
        let ext = [p[0]] + p + [p[p.count - 1]]
        for i in 1..<(ext.count - 2) {
            let p0 = ext[i - 1], p1 = ext[i], p2 = ext[i + 1], p3 = ext[i + 2]
            for s in 0..<samples {
                let t = Double(s) / Double(samples)
                let t2 = t * t, t3 = t2 * t
                let x = 0.5 * ((2*p1.x) + (-p0.x+p2.x)*t + (2*p0.x-5*p1.x+4*p2.x-p3.x)*t2 + (-p0.x+3*p1.x-3*p2.x+p3.x)*t3)
                let y = 0.5 * ((2*p1.y) + (-p0.y+p2.y)*t + (2*p0.y-5*p1.y+4*p2.y-p3.y)*t2 + (-p0.y+3*p1.y-3*p2.y+p3.y)*t3)
                out.append(CGPoint(x: x, y: y))
            }
        }
        out.append(p[p.count - 1])
        return out
    }

    /// A tapered ribbon through `points`. SwiftUI cannot vary stroke width, so
    /// every organic line in this app — stems, vines, traced strokes — is a
    /// filled polygon offset along its normals.
    static func taperedPath(_ points: [CGPoint],
                            widthAt: (CGFloat) -> CGFloat) -> Path {
        guard points.count >= 2 else { return Path() }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        let last = points.count - 1
        for i in 0...last {
            let t = CGFloat(i) / CGFloat(last)
            let prev = points[max(0, i - 1)]
            let next = points[min(last, i + 1)]
            var dx = next.x - prev.x, dy = next.y - prev.y
            let l = max(1e-6, hypot(dx, dy)); dx /= l; dy /= l
            let nx = -dy, ny = dx
            let w = widthAt(t) * 0.5
            left.append(CGPoint(x: points[i].x + nx * w, y: points[i].y + ny * w))
            right.append(CGPoint(x: points[i].x - nx * w, y: points[i].y - ny * w))
        }
        var path = Path()
        path.addLines(left)
        path.addLines(right.reversed())
        path.closeSubpath()
        return path
    }

    /// A leaf in unit space: base at origin, tip at (1, 0), symmetric lens.
    /// Callers supply an affine mapper, and because Bézier curves are
    /// affine-invariant, transforming the control points is exact.
    static func leafPath(length: CGFloat, widthFactor: CGFloat,
                         map: (CGPoint) -> CGPoint) -> Path {
        let w = length * widthFactor
        var p = Path()
        p.move(to: map(.zero))
        p.addQuadCurve(to: map(CGPoint(x: length, y: 0)),
                       control: map(CGPoint(x: length * 0.5, y: -w)))
        p.addQuadCurve(to: map(.zero),
                       control: map(CGPoint(x: length * 0.5, y: w)))
        p.closeSubpath()
        return p
    }

    static func leafMidrib(length: CGFloat, map: (CGPoint) -> CGPoint) -> Path {
        var p = Path()
        p.move(to: map(CGPoint(x: length * 0.06, y: 0)))
        p.addQuadCurve(to: map(CGPoint(x: length * 0.94, y: 0)),
                       control: map(CGPoint(x: length * 0.5, y: -length * 0.02)))
        return p
    }
}

// MARK: - Placement transform
/// Maps a plant's unit space (x ≈ −0.35…0.35, y = 0 at base rising to 1) into
/// view space, applying droop and sway as a rotation about the base.
///
/// Everything is mapped in Swift rather than via GraphicsContext transforms,
/// so line widths stay exact and nothing is silently non-uniformly scaled.
struct PlantPlacement {
    var base: CGPoint
    var height: CGFloat
    var rotation: CGFloat        // radians; +ve leans right

    var widthScale: CGFloat { height * 0.62 }
    private var cosR: CGFloat { CGFloat(cos(Double(rotation))) }
    private var sinR: CGFloat { CGFloat(sin(Double(rotation))) }

    func map(_ p: CGPoint) -> CGPoint {
        let x = p.x * widthScale
        let y = -p.y * height          // unit +y is up; view +y is down
        return CGPoint(x: base.x + x * cosR - y * sinR,
                       y: base.y + x * sinR + y * cosR)
    }

    func rotated(_ v: CGVector) -> CGVector {
        CGVector(dx: v.dx * cosR - v.dy * sinR, dy: v.dx * sinR + v.dy * cosR)
    }

    func len(_ unit: CGFloat) -> CGFloat { unit * height }
}
