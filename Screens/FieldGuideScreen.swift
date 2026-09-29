import SwiftUI

/// S8 — FIELD GUIDE.
///
/// Species are DISCOVERED, never purchased or unlocked by score. Undiscovered
/// ones appear as silhouettes — curiosity, not a checklist.
///
/// There is deliberately no "percentage complete" anywhere. A percentage
/// invites optimisation; a silhouette invites wonder.
struct FieldGuideScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Species.catalogue) { species in
                        card(species)
                    }
                }
                .padding(20)
            }
            .navigationTitle(BloomCopy.guideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(BloomCopy.whyClose) { state.showFieldGuide = false }
                        .font(.bloomCaption)
                }
            }
        }
        .presentationBackground(.regularMaterial)
    }

    @ViewBuilder
    private func card(_ species: Species) -> some View {
        let found = state.garden.garden.discoveredSet.contains(species.id)

        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(found ? 0.06 : 0.03))
                    .frame(width: 76, height: 76)
                Image(systemName: species.symbol)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(found
                        ? AnyShapeStyle(Color(hue: species.hue, saturation: 0.42, brightness: 0.86))
                        : AnyShapeStyle(Color.primary.opacity(0.16)))
                    .symbolEffect(.variableColor.iterative,
                                  options: .repeating,
                                  isActive: found && !reduceMotion && species.kind != .creature)
            }

            VStack(spacing: 3) {
                Text(found ? species.name : "• • •")
                    .font(.bloomMetric)
                    .foregroundStyle(found ? Color.primary : Color.tertiary)
                Text(found ? species.kind.rawValue : BloomCopy.guideUndiscovered)
                    .font(.bloomCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .bloomGlass(.wall, shape: BloomShape.panel(22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? species.name : "Undiscovered species")
        .accessibilityHint(found ? species.kind.rawValue : BloomCopy.guideUndiscovered)
    }
}
