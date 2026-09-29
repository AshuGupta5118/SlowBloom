import SwiftUI

/// INV-2 in one object: a single slow action reverses every negative state.
///
/// The child long-presses for three seconds and the glass clears in sync with
/// their finger. It is a paced-breathing / grounding technique wearing the
/// costume of a button — and it is the reason nothing in SlowBloom is a
/// punishment, because every consequence is immediately repairable.
struct BreathControl: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 92

    var body: some View {
        let progress = state.breathProgress
        let active = state.isBreathing
        let reachedFull = progress >= 1.0

        ZStack {
            Circle()
                .fill(Color(red: 0.56, green: 0.75, blue: 0.42).opacity(0.10 + 0.16 * progress))

            // Progress ring. Grows with the hold, retreats if they let go.
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color(red: 0.62, green: 0.81, blue: 0.93).opacity(0.55 + 0.45 * progress),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Concentric "breath" rings, only while alive.
            if !reduceMotion {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.16 - Double(i) * 0.045), lineWidth: 1.4)
                        .frame(width: size * (0.44 + Double(i) * 0.24) * (1 + 0.03 * progress))
                }
            }

            Image(systemName: BloomSymbol.breathe)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion)
                .scaleEffect(1 + 0.06 * progress)
        }
        .frame(width: size, height: size)
        .bloomGlass(.fitting, shape: BloomShape.circle, fog: 0)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !state.isBreathing { state.beginBreath() } }
                .onEnded { _ in state.endBreath() }
        )
        // Never haptic on the negative state — but the repair IS worth feeling.
        // Never haptic on the NEGATIVE state — but the repair is worth feeling.
        .sensoryFeedback(.impact(flexibility: .soft), trigger: active)
        .sensoryFeedback(.success, trigger: reachedFull)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Breathe")
        .accessibilityHint("Press and hold for three seconds to clear the glass")
        .accessibilityAddTraits(.isButton)
    }
}

/// The caption under the control. Lowercase, one word.
struct BreathLabel: View {
    var body: some View {
        Text(BloomCopy.gardenBreatheCTA)
            .font(.bloomCaption)
            .foregroundStyle(.secondary)
    }
}
