import SwiftUI

/// S1 — "How should SlowBloom feel?"
///
/// Accessibility is the FIRST SCREEN, not a settings menu buried three levels
/// down. Four chips, eight seconds, all reversible from the Guardian view.
/// The model is Pine Hearts (ADA 2026, Inclusivity), which surfaced its
/// inclusivity options before play began.
///
/// A single obvious "just show me" chip lets a visitor skip it — which is how
/// the accessibility system gets DEMONSTRATED to a judge without being imposed.
struct SensoryPickerScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: state.goldenHour
                ? [Color(red: 0.16, green: 0.14, blue: 0.13), Color(red: 0.07, green: 0.07, blue: 0.08)]
                : [Color(red: 0.11, green: 0.13, blue: 0.11), Color(red: 0.05, green: 0.06, blue: 0.06)],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Text(BloomCopy.pickerTitle)
                    .font(.bloomTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                VStack(spacing: 14) {
                    row(title: "Movement", symbol: BloomSymbol.movement,
                        options: SensoryProfile.Movement.allCases,
                        selection: Binding(get: { state.profile.movement },
                                           set: { state.profile.movement = $0 }))
                    row(title: "Sound", symbol: BloomSymbol.sound,
                        options: SensoryProfile.Sound.allCases,
                        selection: Binding(get: { state.profile.sound },
                                           set: { state.profile.sound = $0 }))
                    row(title: "Touch", symbol: BloomSymbol.touch,
                        options: SensoryProfile.Touch.allCases,
                        selection: Binding(get: { state.profile.touch },
                                           set: { state.profile.touch = $0 }))
                    row(title: "Reading", symbol: BloomSymbol.reading,
                        options: SensoryProfile.Reading.allCases,
                        selection: Binding(get: { state.profile.reading },
                                           set: { state.profile.reading = $0 }))
                }
                .frame(maxWidth: 620)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        state.finishOnboarding()
                    } label: {
                        Text(BloomCopy.pickerDone)
                            .font(.bloomPrompt)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 14)
                            .bloomGlass(.fitting,
                                        tint: Color(red: 0.56, green: 0.75, blue: 0.42).opacity(0.30),
                                        shape: BloomShape.pill)
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Sensible defaults, straight in.
                        state.profile = .default
                        state.finishOnboarding()
                    } label: {
                        Text(BloomCopy.pickerJustShowMe)
                            .font(.bloomCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .bloomGlass(.breath, shape: BloomShape.pill)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Uses gentle defaults and goes straight to the garden")
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
    }

    @ViewBuilder
    private func row<T: CaseIterable & Identifiable & Hashable & RawRepresentable>(
        title: String,
        symbol: String,
        options: T.AllCases,
        selection: Binding<T>
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(title)
                    .font(.bloomPrompt)
                    .foregroundStyle(.primary)
            }
            .frame(width: 150, alignment: .leading)

            GlassEffectContainer(spacing: 26) {
                HStack(spacing: 8) {
                    ForEach(Array(options)) { option in
                        let isOn = selection.wrappedValue == option
                        Button {
                            withAnimation(BloomMotion.tap(state.motionScale)) {
                                selection.wrappedValue = option
                            }
                        } label: {
                            Text(label(for: option))
                                .font(.bloomCaption)
                                .fontWeight(isOn ? .semibold : .regular)
                                .foregroundStyle(isOn ? Color.primary : Color.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .bloomGlass(.fitting,
                                            tint: isOn ? Color(red: 0.56, green: 0.75, blue: 0.42).opacity(0.30) : nil,
                                            shape: BloomShape.pill)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(label(for: option)))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Every option already carries its own lowercase label.
    private func label<T>(for option: T) -> String {
        switch option {
        case let o as SensoryProfile.Movement: return o.label
        case let o as SensoryProfile.Sound:    return o.label
        case let o as SensoryProfile.Touch:    return o.label
        case let o as SensoryProfile.Reading:  return o.label
        default: return "\(option)"
        }
    }
}
