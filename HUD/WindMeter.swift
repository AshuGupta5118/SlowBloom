import SwiftUI

/// THE HOOK. The child sees their own swipe velocity rendered as weather
/// inside the jar. That is metacognition, which is the actual mechanism of
/// attention training — and it is the thing no focus timer does.
///
/// Honest units. Real numbers. The child is being shown data about themselves,
/// so the data must look like data: tabular figures, `monospacedDigit`, and
/// digits that roll rather than snap.
struct WindMeter: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let namespace: Namespace.ID

    var body: some View {
        let engine = state.engine

        HStack(spacing: 11) {
            Image(systemName: BloomSymbol.wind)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(gaugeColor)
                .symbolEffect(.wiggle, value: engine.windBucket)
                .symbolEffect(.pulse, options: .repeating, isActive: engine.isSleepy && !reduceMotion)
                .accessibilityHidden(true)

            Text("\(Int(engine.pointerSpeed.rounded()))")
                .font(.bloomMetricBig)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            Text("pt/s")
                .font(.bloomCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            gauge
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .bloomGlass(.fitting, shape: BloomShape.pill, fog: engine.fogLevel)
        .matchedGeometryEffect(id: "hud-wind", in: namespace,
                               isSource: state.activeRitual == nil)
        .animation(BloomMotion.ui(state.motionScale), value: engine.windBucket)
        .animation(BloomMotion.ui(state.motionScale), value: Int(engine.pointerSpeed / 25))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wind")
        .accessibilityValue("\(Int(engine.wind * 100)) percent")
        .accessibilityHint("Shows how fast you are moving your finger")
    }

    private var gaugeColor: Color {
        let w = state.engine.wind
        if w > 0.55 { return Color(red: 0.61, green: 0.63, blue: 0.64) }   // sleepy
        if w > 0.20 { return Color(red: 0.62, green: 0.75, blue: 0.86) }   // water
        return Color(red: 0.56, green: 0.75, blue: 0.42)                   // moss
    }

    private var gauge: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule()
                    .fill(gaugeColor)
                    .frame(width: max(3, proxy.size.width * CGFloat(min(1, state.engine.wind))))
            }
        }
        .frame(width: 66, height: 8)
    }
}
