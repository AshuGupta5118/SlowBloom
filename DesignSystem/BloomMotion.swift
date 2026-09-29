import SwiftUI

/// Every animation in SlowBloom is a spring — except `sleepy`, which is
/// deliberately a damped ease. That asymmetry IS the pedagogy: everything
/// rewarding is quick and bouncy, everything discouraging is slow and heavy.
///
/// Every case takes a scale factor `k` so Golden Hour / Calm Mode can lengthen
/// all motion by 25% from one place, and Reduce Motion can collapse bounce to
/// zero without touching a single call site.
enum BloomMotion {
    /// Touch acknowledgement. Below 0.18s is imperceptible — drop it instead.
    static func tap(_ k: Double = 1) -> Animation { .spring(duration: 0.22 * k, bounce: 0.10) }
    /// UI state change: panel appears, chip selects, mode switches.
    static func ui(_ k: Double = 1) -> Animation { .spring(duration: 0.42 * k, bounce: 0.18) }
    /// Glass morphing between containers.
    static func morph(_ k: Double = 1) -> Animation { .spring(duration: 0.58 * k, bounce: 0.22) }
    /// The reward. The only place bounce is allowed to be this high.
    static func bloom(_ k: Double = 1) -> Animation { .spring(duration: 0.95 * k, bounce: 0.32) }
    /// The negative state. NOT a spring. Deliberately ~3x slower than everything else.
    static func sleepy(_ k: Double = 1) -> Animation { .easeOut(duration: 1.60 * k) }
    /// Reduce Motion replacement for `bloom`.
    static func crossfade(_ k: Double = 1) -> Animation { .easeInOut(duration: 0.25 * k) }

    /// Stagger between siblings. Never stagger more than 8 items.
    static let stagger: Double = 0.045

    /// Chrome: never under 0.18s, never over 1.8s.
    static func clamped(_ d: Double) -> Double { min(max(d, 0.18), 1.8) }

    /// Bounce multiplier: 0 when Reduce Motion is on, else 1.
    static func bounceScale(reduceMotion: Bool, profile: SensoryProfile) -> Double {
        if reduceMotion { return 0 }
        switch profile.movement {
        case .lively: return 1.0
        case .gentle: return 0.55
        case .still:  return 0.0
        }
    }

    /// Duration multiplier: Golden Hour lengthens everything by 25%.
    static func durationScale(profile: SensoryProfile, goldenHour: Bool) -> Double {
        var k = goldenHour ? 1.25 : 1.0
        if profile.movement == .still { k *= 1.15 }
        return k
    }
}
