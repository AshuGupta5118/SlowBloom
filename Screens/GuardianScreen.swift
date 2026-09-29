import SwiftUI

/// S9 — GUARDIAN.
///
/// SF Pro, not SF Rounded: this part is for the grown-up, and the typeface is
/// what says so.
///
/// Gated by a long-press plus simple arithmetic — Apple's standard parental
/// gate pattern. There is NO sign-in, because an app playground that requires
/// sign-in is automatically disqualified, and because FamilyControls needs an
/// entitlement Apple must approve. Everything here is local.
struct GuardianScreen: View {
    @Environment(AppState.self) private var state
    @State private var unlocked = false
    @State private var answer = ""
    @State private var gateError = false
    #if DEBUG
    @State private var selfTestResults: [SelfTest.Result] = []
    #endif

    private let expected = 12   // 7 + 5

    var body: some View {
        NavigationStack {
            Group {
                if unlocked { content } else { gate }
            }
            .navigationTitle(BloomCopy.guardianTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(BloomCopy.whyClose) { state.showGuardian = false }
                        .font(.bloomAdultNote)
                }
            }
        }
        .presentationBackground(.regularMaterial)
    }

    // MARK: Gate

    private var gate: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: BloomSymbol.guardian)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(.secondary)
            Text(BloomCopy.guardianGatePrompt)
                .font(.bloomAdult)
                .multilineTextAlignment(.center)
            TextField("12", text: $answer)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.bloomAdultHead)
                .frame(width: 110)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06)))
                .onChange(of: answer) { _, _ in gateError = false }

            if gateError {
                Text(BloomCopy.guardianGateWrong)
                    .font(.bloomAdultNote)
                    .foregroundStyle(.secondary)   // never red. Not even here.
                    .transition(.opacity)
            }

            Button {
                if Int(answer.trimmingCharacters(in: .whitespaces)) == expected {
                    withAnimation(BloomMotion.ui(state.motionScale)) { unlocked = true }
                } else {
                    answer = ""
                    withAnimation(BloomMotion.tap(state.motionScale)) { gateError = true }
                }
            } label: {
                Text("continue")
                    .font(.bloomAdult)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .bloomGlass(.fitting, shape: BloomShape.pill)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(28)
    }

    // MARK: Content

    private var content: some View {
        Form {
            Section(BloomCopy.guardianCalmTitle) {
                statRow("calm", minutes(state.garden.garden.totalCalmSeconds))
                statRow("traced", minutes(state.garden.garden.totalTracedSeconds))
                statRow("held still", minutes(state.garden.garden.totalStillSeconds))
                statRow("reading", minutes(state.garden.garden.totalReadSeconds))
                statRow("page turns", "\(state.garden.garden.pageTurns)")
            }

            Section(BloomCopy.guardianSensory) {
                Picker("Movement", selection: movementBinding) {
                    ForEach(SensoryProfile.Movement.allCases) { Text($0.label).tag($0) }
                }
                Picker("Sound", selection: soundBinding) {
                    ForEach(SensoryProfile.Sound.allCases) { Text($0.label).tag($0) }
                }
                Picker("Touch", selection: touchBinding) {
                    ForEach(SensoryProfile.Touch.allCases) { Text($0.label).tag($0) }
                }
                Picker("Reading", selection: readingBinding) {
                    ForEach(SensoryProfile.Reading.allCases) { Text($0.label).tag($0) }
                }
            }

            Section {
                Toggle(isOn: directorsCutBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(BloomCopy.guardianDirectors).font(.bloomAdult)
                        Text(BloomCopy.guardianDirectorsNote)
                            .font(.bloomAdultNote)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Calm Mode (Golden Hour)", isOn: calmModeBinding)
            }

            Section(BloomCopy.guardianPrivacyTitle) {
                Text(BloomCopy.guardianPrivacy)
                    .font(.bloomAdultNote)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            Section("Diagnostics") {
                Button("Run self-test") { selfTestResults = SelfTest.runAll() }
                    .font(.bloomAdult)
                if !selfTestResults.isEmpty {
                    ForEach(selfTestResults) { r in
                        HStack(spacing: 10) {
                            Image(systemName: r.passed ? BloomSymbol.check : BloomSymbol.warn)
                                .foregroundStyle(r.passed ? Color.green : Color.orange)
                            Text(r.name).font(.bloomAdultNote)
                            Spacer()
                            if let detail = r.detail {
                                Text(detail).font(.bloomAdultNote).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            #endif

            Section {
                Button("Reset the garden", role: .destructive) {
                    state.garden.resetGarden()
                    state.garden.seedForDirectorsCut()
                }
                .font(.bloomAdult)
            } footer: {
                Text("Nothing here is stored anywhere but this device. There is no account and nothing to delete remotely.")
                    .font(.bloomAdultNote)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.bloomAdult).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.bloomAdult).monospacedDigit()
        }
    }

    private func minutes(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
    }

    // Manual bindings: `profile` is a struct on an @Observable class.
    private var movementBinding: Binding<SensoryProfile.Movement> {
        Binding(get: { state.profile.movement },
                set: { state.profile.movement = $0; SensoryProfileStore.save(state.profile) })
    }
    private var soundBinding: Binding<SensoryProfile.Sound> {
        Binding(get: { state.profile.sound },
                set: { state.profile.sound = $0; SensoryProfileStore.save(state.profile) })
    }
    private var touchBinding: Binding<SensoryProfile.Touch> {
        Binding(get: { state.profile.touch },
                set: { state.profile.touch = $0; SensoryProfileStore.save(state.profile) })
    }
    private var readingBinding: Binding<SensoryProfile.Reading> {
        Binding(get: { state.profile.reading },
                set: { state.profile.reading = $0; SensoryProfileStore.save(state.profile) })
    }
    private var directorsCutBinding: Binding<Bool> {
        Binding(get: { state.directorsCut }, set: { state.directorsCut = $0 })
    }
    private var calmModeBinding: Binding<Bool> {
        Binding(get: { state.calmModeOverride ?? false },
                set: { state.calmModeOverride = $0 })
    }
}
