import Foundation
import Observation

/// The single source of truth. ONE number drives everything: every visual,
/// haptic, audio and growth behaviour in the app reads `calm` and `wind`.
///
/// @Observable and @MainActor because the UI reads it 60x/second. The source
/// is swapped for real sensors in Step 2 without touching this file.
@MainActor
@Observable
final class AttentionEngine {

    private(set) var calm: Double = 0.5
    private(set) var wind: Double = 0.02
    private(set) var pointerSpeed: Double = 0
    private(set) var stillness: Double = 0.5
    private(set) var deliberateness: Double = 0.5

    /// Written by gesture layers each frame. Read by the source.
    var input: AttentionInput = .idle

    private let source: AttentionSource

    init(source: AttentionSource = SimulatedAttentionSource()) {
        self.source = source
    }

    /// Bucketed for animation triggers. Animating on the raw value would fire
    /// 60 times a second and burn the main thread.
    var windBucket: Int { Int((min(1, wind) * 8).rounded()) }
    var calmBucket: Int { Int((min(1, calm) * 8).rounded()) }

    /// Fog threshold. The ambient breeze sits below this on purpose.
    var isSleepy: Bool { wind > 0.06 }
    /// 0…1, how fogged the glass is.
    var fogLevel: Double { min(1, max(0, (wind - 0.06) / 0.60)) }

    func tick(dt: Double) {
        let f = source.sample(dt: dt, input: input)
        calm = f.calm
        wind = f.wind
        pointerSpeed = f.pointerSpeed
        stillness = f.stillness
        deliberateness = f.deliberateness
    }

    func reset() {
        source.reset()
        input = .idle
    }

    /// Used by the Breath control: holding it forces wind down, independent of
    /// the source. The child physically presses their frustration back to calm.
    func breathe(dt: Double, progress: Double) {
        wind = max(0, wind - dt * (0.55 + 0.45 * progress))
        calmEMA_nudge(dt: dt)
    }

    private func calmEMA_nudge(dt: Double) {
        let target = 1.0
        calm += (target - calm) * (1 - exp(-dt / 0.35))
    }
}
