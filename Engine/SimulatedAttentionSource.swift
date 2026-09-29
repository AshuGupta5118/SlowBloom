import Foundation

/// Step 1's stand-in for real sensors. Deliberately models the SAME maths the
/// live source will use (flick detection, exponential wind decay, EMA calm),
/// so nothing downstream has to change when sensors arrive.
///
/// In Step 1, "stillness" is proxied by not touching the screen. That is a
/// real signal — and the deepest one in the app, because SlowBloom's success
/// condition is that the child stops using it. Core Motion refines it later.
final class SimulatedAttentionSource: AttentionSource {

    // Empirical thresholds, to be replaced by measured ones from spike S3.
    // A short-form flick is: very fast, very straight, very short.
    private let flickSpeedFloor: Double = 2200     // pt/s
    private let flickSpeedCeil: Double = 4000      // pt/s at wind = 1.0
    private let windDecayTau: Double = 1.2         // s
    private let calmTau: Double = 0.26             // s (EMA time constant)
    private let windPenalty: Double = 0.6

    private var t: Double = 0
    private var wind: Double = 0
    private var calmEMA: Double = 0.5

    func reset() { t = 0; wind = 0; calmEMA = 0.5 }

    func sample(dt: TimeInterval, input: AttentionInput) -> AttentionFrame {
        t += dt

        // ── Wind ────────────────────────────────────────────────────────────
        let isFlick = input.isTouching && input.pointerSpeed > flickSpeedFloor
        let injected: Double = isFlick
            ? min(1.0, input.pointerSpeed / flickSpeedCeil)
            : 0.0
        // Exponential decay, then take the max with anything just injected.
        wind = max(wind * exp(-dt / windDecayTau), injected)

        // Ambient breeze: the garden is never perfectly dead, but the breeze
        // sits below the fog threshold so it never reads as a negative state.
        let breeze = 0.012 + 0.008 * sin(t * 0.7) + 0.005 * sin(t * 1.9 + 1.3)
        wind = max(wind, max(0, breeze))

        // ── Stillness (Step 1 proxy: not touching) ──────────────────────────
        let stillness: Double
        switch input.ritual {
        case .still: stillness = input.isTouching ? 0.12 : 1.00
        case .trace: stillness = 0.45
        case .read:  stillness = input.isTouching ? 0.20 : 0.85
        case .none:  stillness = input.isTouching ? 0.45 : 0.80
        }

        // ── Context weights sum to 1; wind always subtracts ─────────────────
        var wS = 1.0, wD = 0.0, wF = 0.0
        switch input.ritual {
        case .trace: wS = 0.25; wD = 0.75
        case .still: wS = 1.00
        case .read:  wS = 0.45; wF = 0.55
        case .none:  wS = 1.00
        }
        let deliberate = input.traceDeliberateness ?? 0.5
        let focus = input.focusQuality ?? 0.0

        let raw = wS * stillness + wD * deliberate + wF * focus - windPenalty * wind
        let target = min(1.0, max(0.0, raw))

        // One-pole EMA. alpha derived from dt so it is frame-rate independent.
        let alpha = 1 - exp(-dt / calmTau)
        calmEMA += (target - calmEMA) * alpha

        return AttentionFrame(calm: calmEMA,
                              wind: wind,
                              pointerSpeed: input.pointerSpeed,
                              stillness: stillness,
                              deliberateness: deliberate)
    }
}
