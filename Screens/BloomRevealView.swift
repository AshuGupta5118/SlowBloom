import SwiftUI

/// S6 — BLOOM. The hero animation. Budget a full week for this in P2.
///
/// Petals are placed at the golden angle, not evenly spaced — that is why it
/// reads as a flower rather than a pinwheel. They open staggered 0.045s apart
/// on the `bloom` spring, the only place bounce is allowed to reach 0.32.
///
/// Auto-dismisses on any touch or after four seconds. SlowBloom never praises
/// the child; it names the plant and says how it was made.
struct BloomRevealView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let reveal: GardenStore.PendingReveal
    @State private var opened = false
    @State private var nameShown = false

    private var petalCount: Int { max(5, min(13, reveal.genome.petalCount)) }
    private var hue: Double {
        let base = (Species.catalogue.first { $0.name == reveal.speciesName }?.hue ?? 0.92)
        return (base + reveal.genome.hueShift).truncatingRemainder(dividingBy: 1)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(scheme == .dark ? 0.55 : 0.35)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()
                if reveal.isCreature {
                    creature
                } else {
                    flower
                }
                Spacer()
                VStack(spacing: 6) {
                    Text(reveal.speciesName)
                        .font(.bloomHero)
                        .foregroundStyle(.white)
                        .opacity(nameShown ? 1 : 0)
                        .offset(y: nameShown ? 0 : 10)
                    Text(reveal.provenance)
                        .font(.bloomCaption)
                        .foregroundStyle(.white.opacity(0.72))
                        .opacity(nameShown ? 1 : 0)
                }
                .padding(.bottom, 54)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            let k = state.motionScale
            withAnimation(reduceMotion ? BloomMotion.crossfade(k) : BloomMotion.bloom(k)) {
                opened = true
            }
            withAnimation((reduceMotion ? BloomMotion.crossfade(k) : BloomMotion.ui(k))
                .delay(reduceMotion ? 0.15 : 0.55)) {
                nameShown = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            dismiss()
        }
        .sensoryFeedback(.success, trigger: opened)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reveal.speciesName). \(reveal.provenance)")
        .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        state.garden.consumeReveal()
    }

    private var flower: some View {
        ZStack {
            // Halo
            if !reduceMotion {
                Circle()
                    .fill(Color(hue: max(0, min(1, hue)), saturation: 0.42, brightness: 1.0))
                    .frame(width: 300, height: 300)
                    .blur(radius: 58)
                    .opacity(opened ? 0.42 : 0)
            }
            // Petals at the golden angle
            ForEach(Array(0..<petalCount), id: \.self) { i in
                let angle = Double(i) * PlantGeometry.goldenAngle * 180 / .pi
                Ellipse()
                    .fill(petalGradient)
                    .frame(width: petalWidth, height: petalLength)
                    .offset(y: -petalLength * 0.44)
                    .rotationEffect(.degrees(angle.truncatingRemainder(dividingBy: 360)))
                    .scaleEffect(opened ? 1 : 0.04)
                    .opacity(opened ? 1 : 0)
                    .animation((reduceMotion ? BloomMotion.crossfade(state.motionScale)
                                             : BloomMotion.bloom(state.motionScale))
                        .delay(Double(i) * BloomMotion.stagger),
                        value: opened)
            }
            // Disc floret
            Circle()
                .fill(Color(red: 1.0, green: 0.85, blue: 0.45))
                .frame(width: petalLength * 0.46, height: petalLength * 0.46)
                .scaleEffect(opened ? 1 : 0.1)
                .animation(BloomMotion.bloom(state.motionScale).delay(0.22), value: opened)
            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: petalLength * 0.22, height: petalLength * 0.22)
                .offset(x: -petalLength * 0.06, y: -petalLength * 0.07)
                .opacity(opened ? 1 : 0)
        }
        .frame(width: 320, height: 320)
    }

    private var creature: some View {
        ZStack {
            Image(systemName: BloomSymbol.tortoise)
                .font(.system(size: 150, weight: .regular))
                .foregroundStyle(Color(red: 0.69, green: 0.54, blue: 0.40))
                .symbolEffect(.bounce, value: opened)
                .scaleEffect(opened ? 1 : 0.2)
                .opacity(opened ? 1 : 0)
        }
        .frame(width: 320, height: 320)
    }

    private var petalLength: CGFloat { 132 * CGFloat(0.82 + 0.30 * reveal.genome.sssIntensity) }
    private var petalWidth: CGFloat { petalLength * 0.42 }

    private var petalGradient: LinearGradient {
        let h = max(0, min(1, hue))
        return LinearGradient(colors: [
            Color(hue: h, saturation: 0.22, brightness: 1.00),
            Color(hue: h, saturation: 0.38, brightness: 0.94),
            Color(hue: h, saturation: 0.48, brightness: 0.82)
        ], startPoint: .top, endPoint: .bottom)
    }
}
