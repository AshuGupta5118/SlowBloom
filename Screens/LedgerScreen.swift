import SwiftUI

/// S7 — THE LEDGER.
///
/// A record of what grew. Never of what was missed. Absence is invisible:
/// miss three weeks and the garden is exactly as you left it, with one line
/// that says it waited. No streak, no wilted reminder, no guilt.
struct LedgerScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let entries = state.garden.garden.ledger

        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    List {
                        if waitedLong {
                            Section {
                                Label(BloomCopy.gardenWaited, systemImage: BloomSymbol.moonStars)
                                    .font(.bloomCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            ForEach(entries) { entry in
                                LedgerRow(entry: entry)
                            }
                            .onMove { indices, destination in
                                state.garden.reorderLedger(from: indices, to: destination)
                            }
                        } header: {
                            Text("what grew")
                                .font(.bloomCaption)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(BloomCopy.ledgerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton().font(.bloomCaption)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(BloomCopy.whyClose) { state.showLedger = false }
                        .font(.bloomCaption)
                }
            }
        }
        .presentationBackground(.regularMaterial)
    }

    private var waitedLong: Bool {
        guard let last = state.garden.garden.lastVisited else { return false }
        return Date().timeIntervalSince(last) > 60 * 60 * 24 * 6
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: BloomSymbol.leaf)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(.tertiary)
            Text(BloomCopy.ledgerEmpty)
                .font(.bloomPrompt)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LedgerRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.isCreature ? BloomSymbol.tortoise : BloomSymbol.leaf)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(entry.isCreature
                    ? Color(red: 0.69, green: 0.54, blue: 0.40)
                    : Color(red: 0.45, green: 0.65, blue: 0.36))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.primary.opacity(0.05)))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.subjectName)
                    .font(.bloomMetric)
                    .foregroundStyle(.primary)
                // The provenance line IS the reward: it tells the child HOW
                // they made this, which reinforces the behaviour, not just the
                // outcome. Process praise, not person praise.
                Text(entry.provenance)
                    .font(.bloomCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.bloomCaption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
