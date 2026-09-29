import CoreGraphics
import Foundation

extension Polyline {
    /// Arc-length fraction 0…1 of the sampled point nearest to `p`.
    /// The path is sampled evenly, so index fraction ≈ arc fraction.
    func fraction(nearest p: CGPoint) -> Double {
        guard points.count > 1 else { return 0 }
        var best = 0
        var bestD = CGFloat.greatestFiniteMagnitude
        for (i, pt) in points.enumerated() {
            let d = (pt.x - p.x) * (pt.x - p.x) + (pt.y - p.y) * (pt.y - p.y)
            if d < bestD { bestD = d; best = i }
        }
        return Double(best) / Double(points.count - 1)
    }

    /// Distance in points to the nearest sampled point. Used to decide whether
    /// the finger is actually ON the vine before crediting progress.
    func distance(nearest p: CGPoint) -> CGFloat {
        guard !points.isEmpty else { return .greatestFiniteMagnitude }
        var bestD = CGFloat.greatestFiniteMagnitude
        for pt in points {
            let d = hypot(pt.x - p.x, pt.y - p.y)
            if d < bestD { bestD = d }
        }
        return bestD
    }
}

/// The vine the child traces. Regenerated deterministically from a seed, so a
/// given trace always presents the same path.
struct VinePath {
    let line: Polyline
    let rect: CGRect

    var length: Double { line.length }

    func point(atFraction f: Double) -> CGPoint { line.point(at: f) }
    func tangent(atFraction f: Double) -> CGVector { line.tangent(at: f) }

    /// `complexity` is 3…7 loops, scaled to the child's age band and history.
    static func make(in rect: CGRect, seed: UInt64, complexity: Int) -> VinePath {
        var rng = SeededRNG(seed: seed)
        let loops = max(2, min(7, complexity))
        let samples = 44 * loops
        let amp = rect.height * 0.17
        let phase = rng.range(0, .pi * 2)
        let tilt = rng.range(-0.18, 0.18)

        var pts: [CGPoint] = []
        pts.reserveCapacity(samples + 1)
        for i in 0...samples {
            let t = Double(i) / Double(samples)
            let x = rect.minX + CGFloat(t) * rect.width
            // Amplitude tapers at the ends so the vine lands cleanly.
            let envelope = sin(t * .pi)
            let y = rect.midY
                + sin(t * .pi * 2 * Double(loops) * 0.5 + phase) * amp * CGFloat(envelope)
                + CGFloat(t * tilt) * rect.height * 0.22
                + CGFloat(rng.range(-3.5, 3.5))
            pts.append(CGPoint(x: x, y: y))
        }
        return VinePath(line: Polyline(points: pts), rect: rect)
    }

    /// The pace the pollen spark travels, in points per second. Derived from
    /// the path so a Taste-length trace always fits its 20 seconds.
    func targetSpeed(forSeconds seconds: Double) -> Double {
        min(260, max(120, length / max(6, seconds)))
    }
}
