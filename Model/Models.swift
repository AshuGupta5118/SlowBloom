import Foundation
import SwiftUI

// MARK: - Species

struct Species: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable { case flower, fern, sapling, creature }

    let id: String
    /// Lowercase, always. Never ALL CAPS, never Title Case.
    let name: String
    let kind: Kind
    /// Base hue 0…1, used by the procedural renderer.
    let hue: Double
    /// Logistic growth rate. Seedlings rocket; mature plants barely move.
    let r: Double
    let gMax: Double
    /// Rough silhouette used by the Field Guide and the 2D renderer.
    let frondCount: Int
    let maxPetalCount: Int
    let symbol: String

    static let catalogue: [Species] = [
        Species(id: "moonpetal", name: "moonpetal", kind: .flower, hue: 0.92,
                r: 0.16, gMax: 1.0, frondCount: 4, maxPetalCount: 13,
                symbol: BloomSymbol.sparkles),
        Species(id: "fernling", name: "fernling", kind: .fern, hue: 0.42,
                r: 0.22, gMax: 1.0, frondCount: 7, maxPetalCount: 0,
                symbol: BloomSymbol.leaf),
        Species(id: "oakling", name: "oakling", kind: .sapling, hue: 0.09,
                r: 0.07, gMax: 1.0, frondCount: 5, maxPetalCount: 0,
                symbol: BloomSymbol.seedling),
        Species(id: "mossback", name: "mossback", kind: .creature, hue: 0.30,
                r: 0, gMax: 1, frondCount: 0, maxPetalCount: 0,
                symbol: BloomSymbol.tortoise)
    ]

    static func byID(_ id: String) -> Species? { catalogue.first { $0.id == id } }
    static let plants: [Species] = catalogue.filter { $0.kind != .creature }
    static let creatures: [Species] = catalogue.filter { $0.kind == .creature }

    /// Which species a ritual yields. `.read` yields the rarest.
    static func reward(for ritual: RitualKind, discovered: Set<String>) -> Species {
        let order: [String]
        switch ritual {
        case .trace: order = ["moonpetal", "fernling", "oakling"]
        case .still: order = ["fernling", "oakling", "moonpetal"]
        case .read:  order = ["oakling", "moonpetal", "fernling"]
        }
        let fresh = order.first { !discovered.contains($0) } ?? order[0]
        return byID(fresh) ?? catalogue[0]
    }
}

// MARK: - Rituals

enum RitualKind: String, Codable, CaseIterable, Identifiable {
    case trace, still, read
    var id: String { rawValue }

    /// The judge sees `taste`. The child does `full`. Same code path,
    /// different target — never a mock or a stub.
    var tasteSeconds: Double { 20 }
    var fullSeconds: Double {
        switch self { case .trace: 60; case .still: 90; case .read: 120 }
    }
    func target(directorsCut: Bool) -> Double { directorsCut ? tasteSeconds : fullSeconds }

    var symbol: String {
        switch self {
        case .trace: BloomSymbol.trace
        case .still: BloomSymbol.still
        case .read:  BloomSymbol.read
        }
    }
    var label: String {
        switch self { case .trace: "Trace"; case .still: "Be still"; case .read: "Read" }
    }
    var prompt: String {
        switch self {
        case .trace: BloomCopy.traceTitle
        case .still: BloomCopy.stillTitle
        case .read:  BloomCopy.readTitle
        }
    }
}

// MARK: - Genome
/// The child's own motor signature becomes the seed. Because plants are
/// generated rather than modelled, a calmly-traced flower is LITERALLY,
/// VISIBLY, UNIQUELY more complex than a rushed one — and no two are ever
/// identical, so the ledger becomes a gallery rather than a list.
struct PlantGenome: Codable, Hashable {
    var seed: UInt64
    var petalCount: Int
    /// 0…1. Higher = more graceful irregularity. From speed coefficient of variation.
    var asymmetry: Double
    var stemCurvature: Double
    /// ±~16° of hue. From pressure stability.
    var hueShift: Double
    var leafCount: Int
    /// Subsurface glow. From total duration.
    var sssIntensity: Double

    static let standard = PlantGenome(seed: 0x5EED_B100, petalCount: 6, asymmetry: 0.35,
                                      stemCurvature: 0.30, hueShift: 0, leafCount: 4,
                                      sssIntensity: 0.45)

    static func from(deliberateness d: Double,
                     lifts: Int,
                     seconds: Double,
                     seed: UInt64) -> PlantGenome {
        let q = min(max(d, 0), 1)
        return PlantGenome(
            seed: seed,
            petalCount: 5 + Int((q * 8).rounded()),                  // 5…13
            asymmetry: 0.15 + q * 0.55,
            stemCurvature: 0.15 + q * 0.50,
            hueShift: (q - 0.5) * 0.045,
            leafCount: max(2, 7 - lifts),
            sssIntensity: min(1.0, 0.25 + q * 0.45 + seconds / 240.0))
    }
}

// MARK: - Garden entities

struct Plant: Identifiable, Codable, Hashable {
    let id: UUID
    var speciesID: Species.ID
    var genome: PlantGenome
    /// INV-1: monotonically non-decreasing. Nothing is ever lost.
    var growth: Double
    /// Normalised position inside the jar, 0…1 on both axes.
    var position: CGPoint
    /// Pose only. Never touches `growth`.
    var sleepiness: Double
    var plantedAt: Date

    var species: Species { Species.byID(speciesID) ?? Species.catalogue[0] }
    var maturity: Double { min(1, growth / max(0.0001, species.gMax)) }

    static func new(_ species: Species, genome: PlantGenome, at position: CGPoint) -> Plant {
        Plant(id: UUID(), speciesID: species.id, genome: genome, growth: 0.02,
              position: position, sleepiness: 0, plantedAt: Date())
    }
}

struct Creature: Identifiable, Codable, Hashable {
    let id: UUID
    var speciesID: String
    var name: String
    /// Normalised position; wanders via NavMesh in Step 4.
    var position: CGPoint
    var bornAt: Date
    var approach: Double      // 0…1, how close to the glass it has come

    static func new(_ species: Species, at position: CGPoint) -> Creature {
        Creature(id: UUID(), speciesID: species.id, name: species.name,
                 position: position, bornAt: Date(), approach: 0)
    }
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var subjectName: String
    /// The provenance line IS the reward: it tells the child HOW they made
    /// this, which reinforces the behaviour rather than just the outcome.
    var provenance: String
    var genome: PlantGenome?
    var isCreature: Bool

    static func plant(_ p: Plant, provenance: String) -> LedgerEntry {
        LedgerEntry(id: UUID(), date: Date(), subjectName: p.species.name,
                    provenance: provenance, genome: p.genome, isCreature: false)
    }
    static func creature(_ c: Creature) -> LedgerEntry {
        LedgerEntry(id: UUID(), date: Date(), subjectName: c.name,
                    provenance: BloomCopy.creatureBorn, genome: nil, isCreature: true)
    }
}

// MARK: - Garden

struct Garden: Codable {
    /// Version the schema from day one. A judge launching an older build over
    /// a newer file must not crash.
    var schemaVersion: Int = 1
    var plants: [Plant] = []
    var creatures: [Creature] = []
    var ledger: [LedgerEntry] = []
    var discovered: [String] = []
    /// Aggregate only. Never a sensor trace. This is a privacy commitment.
    var totalCalmSeconds: Double = 0
    var totalTracedSeconds: Double = 0
    var totalStillSeconds: Double = 0
    var totalReadSeconds: Double = 0
    var pageTurns: Int = 0
    var createdAt: Date = Date()
    /// Absence is invisible. We record when the child was last here so we can
    /// say "It waited for you" — and never how long they were away.
    var lastVisited: Date?

    var discoveredSet: Set<String> { Set(discovered) }

    mutating func markDiscovered(_ id: String) {
        if !discovered.contains(id) { discovered.append(id) }
    }
}

// NOTE: CGPoint, CGSize, CGRect and CGAffineTransform already conform to
// Codable on Apple platforms (CoreGraphics). Do NOT redeclare it — a
// retroactive conformance here is a duplicate-conformance compile error.
