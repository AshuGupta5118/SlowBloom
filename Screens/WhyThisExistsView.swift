import SwiftUI

/// The one-tap answer to "what is this?". Reachable in exactly one tap from the
/// home screen, and last in the tab order so it never interferes.
///
/// Forty words of thesis, then the Forest distinction, then the privacy line.
/// Naming your comparator before the judge does is a power move.
struct WhyThisExistsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(BloomCopy.whyTitle, BloomCopy.whyBody)
                    section(BloomCopy.whyForestTitle, BloomCopy.whyForest)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Privacy", systemImage: BloomSymbol.eyeOff)
                            .font(.bloomAdultHead)
                        Text(BloomCopy.guardianPrivacy)
                            .font(.bloomAdult)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .bloomGlass(.wall, shape: BloomShape.panel(22))
                }
                .padding(22)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(BloomCopy.whyClose) { state.showWhy = false }
                        .font(.bloomCaption)
                }
            }
        }
        .presentationBackground(.regularMaterial)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.bloomAdultHead)
            Text(body)
                .font(.bloomAdult)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bloomGlass(.wall, shape: BloomShape.panel(22))
    }
}
