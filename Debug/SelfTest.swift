#if DEBUG
import Foundation

/// Layer 2 of the two-layer test strategy.
///
/// XCTest cannot live inside an app playground — Swift Playgrounds has no
/// XCTest — so the load-bearing invariants are ALSO encoded here, where they
/// run on the iPad, inside Swift Playgrounds, in the real judging runtime.
/// Run it from Guardian → Diagnostics at the top of every device session.
///
/// Layer 1 (`SlowBloomTests.xcodeproj`, outside the .swiftpm, referencing these
/// same files) asserts the same things on the Mac with proper XCTest.
///
/// ⚠️ DELETE THIS FILE and the `#if DEBUG` Diagnostics section of
/// GuardianScreen.swift before packaging the submission.
@MainActor
enum SelfTest {

    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        var detail: String? = nil
    }

    static func runAll() -> [Result] {
        [
            growthIsMonotonic(),
            sleepyRecoversInTime(),
            sleepyIsSlowerOutThanIn(),
            copyWithinLimits(),
            copyHasNoBannedWords(),
            gardenRoundTrips(),
            generationIsDeterministic(),
            genomeRespondsToDeliberateness(),
            flickRaisesWindAndDecays(),
            catalogueIsSane()
        ]
    }

    // MARK: INV-1 — nothing is ever lost

    private static func growthIsMonotonic() -> Result {
        var rng = SeededRNG(seed: 0x1A2B_3C4D)
        var g = 0.0
        var previous = 0.0
        var steps = 0
        for _ in 0..<10_000 {
            let calm = rng.unit()
            let wind = rng.unit()          // wind must never reduce growth
            g = GardenStore.growthStep(current: g, calm: calm, dt: 1.0 / 60.0,
                                       r: 0.16, gMax: 1.0)
            _ = wind
            steps += 1
            if g < previous - 1e-12 {
                return Result(name: "INV-1 growth monotonic", passed: false,
                              detail: "decreased at step \(steps)")
            }
            if g > 1.0 + 1e-9 {
                return Result(name: "INV-1 growth monotonic", passed: false,
                              detail: "exceeded gMax at step \(steps)")
            }
            previous = g
        }
        return Result(name: "INV-1 growth monotonic", passed: true,
                      detail: "10,000 steps, g = \(String(format: "%.3f", g))")
    }

    // MARK: INV-2 — every negative state is reversible in under 10 s

    private static func sleepyRecoversInTime() -> Result {
        var level = 1.0
        var t = 0.0
        while level > 0.02 && t < 12.0 {
            level = GardenStore.sleepinessStep(current: level, target: 0.0, dt: 1.0 / 60.0)
            t += 1.0 / 60.0
        }
        return Result(name: "INV-2 sleepy clears < 8s", passed: t <= 8.0,
                      detail: String(format: "%.2fs to 2%%", t))
    }

    private static func sleepyIsSlowerOutThanIn() -> Result {
        // Fast in: 63% of the way in tau_rise.
        let rise = GardenStore.sleepinessStep(current: 0.0, target: 1.0, dt: 0.30)
        // Slow out: after the same 0.30 s it must have moved far less.
        let fall = 1.0 - GardenStore.sleepinessStep(current: 1.0, target: 0.0, dt: 0.30)
        return Result(name: "Asymmetry: fast in, slow out", passed: rise > fall * 2.0,
                      detail: String(format: "in %.2f vs out %.2f", rise, fall))
    }

    // MARK: Copy discipline

    private static func copyWithinLimits() -> Result {
        var failures: [String] = []
        for s in BloomCopy.childFacing {
            let words = s.split(whereSeparator: { $0.isWhitespace }).count
            if words > 8 { failures.append(">\(8)w: “\(s)”") }
            if s.count > 34 { failures.append(">\(34)c: “\(s)”") }
            if s.contains("!") { failures.append("!: “\(s)”") }
        }
        return Result(name: "Copy ≤ 8 words / ≤ 34 chars",
                      passed: failures.isEmpty,
                      detail: failures.isEmpty ? "\(BloomCopy.childFacing.count) strings" : failures.joined(separator: "; "))
    }

    private static func copyHasNoBannedWords() -> Result {
        var hits: [String] = []
        for s in BloomCopy.childFacing {
            let lower = s.lowercased()
            for banned in BloomCopy.bannedWords where lower.contains(banned) {
                hits.append("\(banned) in “\(s)”")
            }
        }
        return Result(name: "No punitive vocabulary", passed: hits.isEmpty,
                      detail: hits.isEmpty ? nil : hits.joined(separator: "; "))
    }

    // MARK: Persistence

    private static func gardenRoundTrips() -> Result {
        var garden = Garden()
        let sp = Species.byID("moonpetal")!
        let genome = PlantGenome.from(deliberateness: 0.82, lifts: 0, seconds: 61,
                                      seed: 0xABCD_1234)
        garden.plants.append(.new(sp, genome: genome, at: CGPoint(x: 0.5, y: 0.88)))
        garden.creatures.append(.new(Species.byID("mossback")!, at: CGPoint(x: 0.7, y: 0.86)))
        garden.ledger.append(.plant(garden.plants[0], provenance: BloomCopy.provenanceTrace(61)))
        garden.totalCalmSeconds = 1234.5

        do {
            let data = try JSONEncoder().encode(garden)
            let back = try JSONDecoder().decode(Garden.self, from: data)
            let ok = back.plants.first?.genome == genome
                && back.plants.first?.position.x == 0.5
                && back.creatures.count == 1
                && back.ledger.count == 1
                && abs(back.totalCalmSeconds - 1234.5) < 0.001
            return Result(name: "Garden round-trips", passed: ok,
                          detail: "\(data.count) bytes")
        } catch {
            return Result(name: "Garden round-trips", passed: false, detail: "\(error)")
        }
    }

    // MARK: Procedural generation

    private static func generationIsDeterministic() -> Result {
        let sp = Species.byID("moonpetal")!
        let genome = PlantGenome.from(deliberateness: 0.7, lifts: 1, seconds: 40, seed: 42)
        let a = PlantGeometry.structure(genome: genome, species: sp)
        let b = PlantGeometry.structure(genome: genome, species: sp)
        guard a.stem.points.count == b.stem.points.count, a.stem.points.count > 3 else {
            return Result(name: "Generation deterministic", passed: false, detail: "point count differs")
        }
        for i in 0..<a.stem.points.count {
            if abs(a.stem.points[i].x - b.stem.points[i].x) > 1e-9 {
                return Result(name: "Generation deterministic", passed: false, detail: "diverges at \(i)")
            }
        }
        return Result(name: "Generation deterministic", passed: true,
                      detail: "\(a.stem.points.count) pts, \(a.leaves.count) leaves")
    }

    /// The mechanic that matters: a calmer trace must produce a MORE complex
    /// flower. Delayed gratification as a property of the geometry.
    private static func genomeRespondsToDeliberateness() -> Result {
        let rushed = PlantGenome.from(deliberateness: 0.15, lifts: 3, seconds: 12, seed: 7)
        let calm = PlantGenome.from(deliberateness: 0.95, lifts: 0, seconds: 60, seed: 7)
        let ok = calm.petalCount > rushed.petalCount
            && calm.leafCount > rushed.leafCount
            && calm.sssIntensity > rushed.sssIntensity
        return Result(name: "Calmer trace → richer flower", passed: ok,
                      detail: "petals \(rushed.petalCount)→\(calm.petalCount), leaves \(rushed.leafCount)→\(calm.leafCount)")
    }

    // MARK: Sensor fusion (Step 1: simulated source, Step 2: replay harness)

    private static func flickRaisesWindAndDecays() -> Result {
        let source = SimulatedAttentionSource()
        var wind = 0.0
        var flick = AttentionInput()
        flick.isTouching = true
        flick.pointerSpeed = 3000
        for _ in 0..<12 { wind = source.sample(dt: 1.0 / 60.0, input: flick).wind }
        guard wind > 0.5 else {
            return Result(name: "Flick detection", passed: false,
                          detail: String(format: "peak wind only %.2f", wind))
        }
        let idle = AttentionInput()
        var t = 0.0
        while wind > 0.10 && t < 8.0 {
            wind = source.sample(dt: 1.0 / 60.0, input: idle).wind
            t += 1.0 / 60.0
        }
        return Result(name: "Flick detection + decay", passed: t <= 5.0,
                      detail: String(format: "peak %.2f, decayed in %.2fs", wind, t))
    }

    private static func catalogueIsSane() -> Result {
        let ids = Species.catalogue.map(\.id)
        let unique = Set(ids).count == ids.count
        var resolvable = true
        for ritual in RitualKind.allCases {
            let reward = Species.reward(for: ritual, discovered: [])
            if Species.byID(reward.id) == nil { resolvable = false }
        }
        return Result(name: "Species catalogue", passed: unique && resolvable,
                      detail: "\(ids.count) species")
    }
}
#endif
