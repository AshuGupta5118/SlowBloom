import SwiftUI

/// The three ritual chips, rising from the bottom edge.
///
/// `GlassEffectContainer` with spacing LARGER than the interior stack makes the
/// chips blend at rest and morph apart when one is chosen — that fluid merge is
/// the most recognisable Liquid Glass behaviour there is.
struct RitualDock: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let namespace: Namespace.ID

    var body: some View {
        GlassEffectContainer(spacing: 34) {
            HStack(spacing: 14) {
                ForEach(RitualKind.allCases) { kind in
                    chip(kind)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ kind: RitualKind) -> some View {
        // Reading Glass needs the camera, which arrives in Step 3. It is shown
        // dimmed with an honest reason rather than hidden — hiding it would
        // look like a broken button.
        let available = (kind != .read)

        Button {
            guard available else { state.showReadStub = true; return }
            state.beginRitual(kind)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: kind.symbol)
                    .font(.system(.title3, design: .rounded))
                    .symbolEffect(.bounce, value: state.garden.garden.plants.count)
                Text(kind.label)
                    .font(.bloomCaption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(available ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .frame(width: 96, height: 62)
            .bloomGlass(.fitting, shape: BloomShape.panel(22))
        }
        .buttonStyle(.plain)
        .disabled(false)   // stays tappable so it can explain itself
        .accessibilityLabel(Text(kind.label))
        .accessibilityHint(Text(available ? "Starts the ritual" : BloomCopy.readStubTitle))
    }
}

/// The one instruction line. Never two instructions on a screen.
struct PromptBanner: View {
    let text: String
    @Environment(AppState.self) private var state

    var body: some View {
        Text(text)
            .font(.bloomPrompt)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .bloomGlass(.wall, shape: BloomShape.pill, fog: state.engine.fogLevel * 0.6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(text))
    }
}

/// Small labelled glass button used across the screens.
struct GlassIconButton: View {
    let symbol: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(label)
                    .font(.bloomCaption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .bloomGlass(.fitting, shape: BloomShape.pill)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
