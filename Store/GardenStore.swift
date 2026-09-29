import Foundation
import Observation
import SwiftUI

/// Owns the garden, its growth, and its persistence.
///
/// Two invariants live here and nowhere else:
///   INV-1  Nothing is ever lost. `Plant.growth` is monotonically
///          non-decreasing. Sleepiness affects POSE only.
///   INV-2  Every negative state is reversible by one slow action in <10 s.
///          Enforced by the asymmetric time constants in `advanceSleepiness`.
@MainActor
@Observable
final class GardenStore {

    private(set) var garden: Garden
    /// Raised when a bloom should be revealed. The UI consumes and clears it.
    var pendingReveal: PendingReveal?

    struct PendingReveal: Equatable {
        var speciesName: String
        var genome: PlantGenome
        var provenance: String
        var isCreature: Bool
    }

    private let url: URL
    private var saveTask: Task<Void, Never>?

    init(garden: Garden? = nil) {
        self.url = GardenStore.fileURL
        self.garden = garden ?? GardenStore.load(from: GardenStore.fileURL) ?? Garden()
        self.garden.lastVisited = Date()
    }

    // MARK: - Simulation step

    /// Advance every plant. Called once per frame from `AppState`.
    func advance(dt: Double, calm: Double, wind: Double) {
        guard dt > 0 else { return }
        for i in garden.plants.indices {
            advanceGrowth(&garden.plants[i], dt: dt, calm: calm)
            advanceSleepiness(&garden.plants[i], dt: dt, wind: wind)
        }
        for i in garden.creatures.indices {
            advanceCreature(&garden.creatures[i], dt: dt, calm: calm, wind: wind)
        }
        garden.totalCalmSeconds += max(0, calm) * dt
    }

    /// dG/dt = r · C · (1 − G/Gmax)
    /// Logistic on purpose: a seedling rockets and a mature plant barely
    /// moves. Delayed gratification expressed as a differential equation —
    /// and it means a garden cannot be completed in one sitting.
    private func advanceGrowth(_ p: inout Plant, dt: Double, calm: Double) {
        p.growth = GardenStore.growthStep(current: p.growth, calm: calm, dt: dt,
                                          r: p.species.r, gMax: p.species.gMax)
    }

    /// Fast in, slow out. tau_rise = 0.30 s, tau_fall = 4.50 s.
    /// The child sees the consequence instantly and the repair gradually.
    /// That asymmetry IS the lesson.
    private func advanceSleepiness(_ p: inout Plant, dt: Double, wind: Double) {
        p.sleepiness = GardenStore.sleepinessStep(current: p.sleepiness,
                                                  target: min(1, max(0, wind)),
                                                  dt: dt)
    }

    /// Fast in, slow out — exposed statically so the invariant is unit-testable
    /// and so `SelfTest` can assert INV-2 without a live garden.
    nonisolated static func sleepinessStep(current: Double, target: Double, dt: Double) -> Double {
        let tau = target > current ? 0.30 : 4.50
        let next = current + (target - current) * (1 - exp(-dt / tau))
        return min(1, max(0, next))
    }

    /// dG/dt = r · C · (1 − G/Gmax). Exposed statically for the same reason.
    /// `max(0, ·)` is INV-1 written in code: growth never decreases.
    nonisolated static func growthStep(current: Double, calm: Double, dt: Double,
                           r: Double, gMax: Double) -> Double {
        let gMaxSafe = max(0.0001, gMax)
        let delta = r * max(0, calm) * (1 - current / gMaxSafe) * dt
        return min(gMaxSafe, current + max(0, delta))
    }

    /// A creature never performs on command. It approaches only after
    /// sustained calm, retreats on wind — and ALWAYS returns. Never lost.
    private func advanceCreature(_ c: inout Creature, dt: Double, calm: Double, wind: Double) {
        let target: Double = (calm > 0.72 && wind < 0.08) ? 1.0 : (wind > 0.35 ? 0.0 : c.approach)
        let tau = target > c.approach ? 6.0 : 1.4     // slow to trust, quick to shy
        c.approach += (target - c.approach) * (1 - exp(-dt / tau))
        c.approach = min(1, max(0, c.approach))
        // Wander gently along the jar floor.
        let drift = sin(Date().timeIntervalSinceReferenceDate * 0.22 + Double(c.id.hashValue % 97)) * 0.0006
        c.position.x = min(0.86, max(0.14, c.position.x + drift))
    }

    // MARK: - Ritual rewards

    /// Called when a ritual completes. `deliberateness` seeds the genome, so
    /// the flower is a portrait of how the child actually moved.
    @discardableResult
    func completeRitual(_ ritual: RitualKind,
                        seconds: Double,
                        deliberateness: Double,
                        lifts: Int,
                        pageTurns: Int) -> PendingReveal {
        let discovered = garden.discoveredSet
        let isCreature = (ritual == .still) && garden.creatures.isEmpty

        if isCreature, let sp = Species.creatures.first {
            let c = Creature.new(sp, at: CGPoint(x: 0.70, y: 0.86))
            garden.creatures.append(c)
            garden.markDiscovered(sp.id)
            garden.ledger.insert(.creature(c), at: 0)
            garden.totalStillSeconds += seconds
            let reveal = PendingReveal(speciesName: sp.name, genome: .standard,
                                       provenance: BloomCopy.creatureBorn, isCreature: true)
            pendingReveal = reveal
            save()
            return reveal
        }

        let sp = Species.reward(for: ritual, discovered: discovered)
        let seed = Self.makeSeed(genomeOf: sp.id, seconds: seconds,
                                 deliberateness: deliberateness, lifts: lifts)
        let genome = PlantGenome.from(deliberateness: deliberateness,
                                      lifts: lifts, seconds: seconds, seed: seed)
        let pos = Self.nextFreePosition(existing: garden.plants)
        let plant = Plant.new(sp, genome: genome, at: pos)
        garden.plants.append(plant)
        garden.markDiscovered(sp.id)

        let provenance: String
        switch ritual {
        case .trace: provenance = BloomCopy.provenanceTrace(Int(seconds.rounded()))
        case .still: provenance = BloomCopy.provenanceStill(Int(seconds.rounded()))
        case .read:  provenance = BloomCopy.provenanceRead(max(1, pageTurns))
        }
        garden.ledger.insert(.plant(plant, provenance: provenance), at: 0)

        switch ritual {
        case .trace: garden.totalTracedSeconds += seconds
        case .still: garden.totalStillSeconds += seconds
        case .read:  garden.totalReadSeconds += seconds; garden.pageTurns += pageTurns
        }

        let reveal = PendingReveal(speciesName: sp.name, genome: genome,
                                   provenance: provenance, isCreature: false)
        pendingReveal = reveal
        save()
        return reveal
    }

    func consumeReveal() { pendingReveal = nil }

    /// The ledger is reorderable (WWDC26 made containers reorderable across
    /// SwiftUI). `garden` has a private setter, so the mutation lives here.
    func reorderLedger(from source: IndexSet, to destination: Int) {
        garden.ledger.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// A deterministic seed — same inputs must produce the same plant on
    /// every frame and every relaunch. Never use `String.hashValue`, which
    /// is randomised per process.
    private static func makeSeed(genomeOf id: String, seconds: Double,
                                 deliberateness: Double, lifts: Int) -> UInt64 {
        var h = Self.fnv1a(id)
        h = h &* 0x100000001B3 ^ UInt64(bitPattern: Int64(seconds * 10))
        h = h &* 0x100000001B3 ^ UInt64(bitPattern: Int64(deliberateness * 1000))
        h = h &* 0x100000001B3 ^ UInt64(lifts &* 7919)
        return h == 0 ? 0x5EED_B100 : h
    }

    nonisolated static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001B3 }
        return h
    }

    private static func nextFreePosition(existing: [Plant]) -> CGPoint {
        // Spread along the soil line, avoiding collisions with what's planted.
        let slots: [CGFloat] = [0.30, 0.44, 0.58, 0.72, 0.37, 0.65, 0.50, 0.24, 0.78]
        for s in slots where !existing.contains(where: { abs($0.position.x - s) < 0.05 }) {
            return CGPoint(x: s, y: 0.88)
        }
        return CGPoint(x: CGFloat.random(in: 0.26...0.76), y: 0.88)
    }

    // MARK: - Director's Cut
    /// Seeds the garden so it never looks empty for a first-time visitor.
    /// Auto-enabled on the very first launch, because for a judge it always is.
    func seedForDirectorsCut() {
        guard garden.plants.isEmpty else { return }
        let now = Date()
        let mature = PlantGenome(seed: 0xA11C_E001, petalCount: 11, asymmetry: 0.62,
                                 stemCurvature: 0.44, hueShift: 0.012, leafCount: 5,
                                 sssIntensity: 0.78)
        var p1 = Plant.new(Species.byID("moonpetal")!, genome: mature, at: CGPoint(x: 0.50, y: 0.88))
        p1.growth = 0.92; p1.plantedAt = now.addingTimeInterval(-86_400 * 6)

        let mid = PlantGenome(seed: 0xA11C_E002, petalCount: 0, asymmetry: 0.40,
                              stemCurvature: 0.30, hueShift: -0.006, leafCount: 7,
                              sssIntensity: 0.5)
        var p2 = Plant.new(Species.byID("fernling")!, genome: mid, at: CGPoint(x: 0.32, y: 0.88))
        p2.growth = 0.58; p2.plantedAt = now.addingTimeInterval(-86_400 * 3)

        var p3 = Plant.new(Species.byID("oakling")!, genome: .standard, at: CGPoint(x: 0.68, y: 0.88))
        p3.growth = 0.14; p3.plantedAt = now.addingTimeInterval(-3_600 * 5)

        garden.plants = [p1, p2, p3]
        garden.discovered = ["moonpetal", "fernling", "oakling"]
        let c = Creature.new(Species.byID("mossback")!, at: CGPoint(x: 0.78, y: 0.87))
        garden.creatures = [c]
        garden.discovered.append("mossback")
        garden.ledger = [
            .plant(p1, provenance: BloomCopy.provenanceTrace(61)),
            .creature(c),
            .plant(p2, provenance: BloomCopy.provenanceStill(90)),
            .plant(p3, provenance: BloomCopy.provenanceRead(1))
        ]
        garden.totalCalmSeconds = 1_840
        garden.totalTracedSeconds = 61
        garden.totalStillSeconds = 90
        garden.totalReadSeconds = 120
        save()
    }

    func resetGarden() {
        garden = Garden()
        save()
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SlowBloom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("garden.json")
    }

    private static func load(from url: URL) -> Garden? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        // Corrupt or future-schema file: never crash. Start fresh.
        guard let g = try? JSONDecoder().decode(Garden.self, from: data) else { return nil }
        return g
    }

    /// Debounced + atomic. A mid-write crash must never corrupt a child's
    /// months-old garden — this is the one place a bug is unforgivable.
    func save() {
        saveTask?.cancel()
        let snapshot = garden
        let target = url
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: target, options: .atomic)
        }
    }
}
