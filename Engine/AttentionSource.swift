import Foundation

/// What the UI layer observed this frame. Written by gesture handlers,
/// read by the source. This struct is the ONLY channel from views into the
/// attention model.
struct AttentionInput {
    /// Is a finger / Pencil currently on the glass?
    var isTouching: Bool = false
    /// Live pointer velocity, pt/s. Honest units, shown to the child.
    var pointerSpeed: Double = 0
    /// Set only while a trace ritual is active. 0…1.
    var traceDeliberateness: Double? = nil
    /// Set only while Reading Glass is active. 0…1.
    var focusQuality: Double? = nil
    /// Number of times the finger lifted during the current trace.
    var liftCount: Int = 0
    var ritual: RitualKind? = nil

    static let idle = AttentionInput()
}

/// One fused frame. Everything downstream reads this.
struct AttentionFrame {
    var calm: Double = 0.5
    var wind: Double = 0.02
    var pointerSpeed: Double = 0
    var stillness: Double = 0.5
    var deliberateness: Double = 0.5
}

// ─────────────────────────────────────────────────────────────────────────────
// THE SEAM.
//
// Step 1 ships `SimulatedAttentionSource` so the entire UI is alive with no
// sensors and no permissions.
//
// Step 2 adds `LiveAttentionSource` (Core Motion + gesture + PencilKit).
// Step 2 also adds `ReplayAttentionSource`, which reads the 12 recorded
// .json motion traces and feeds them through THIS SAME protocol — so the
// fusion maths is developed and unit-tested on a Mac with no device present.
//
// Nothing above this file changes when that swap happens.
// ─────────────────────────────────────────────────────────────────────────────
protocol AttentionSource: AnyObject {
    /// Called ~60 Hz on the main actor. Must be cheap and side-effect free
    /// apart from its own internal state.
    func sample(dt: TimeInterval, input: AttentionInput) -> AttentionFrame
    func reset()
}
