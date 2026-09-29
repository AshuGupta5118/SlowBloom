import SwiftUI

/// S2 — THE TERRARIUM. The home screen and the hero.
///
/// Composition is strict: background → world → glass → text. The terrarium
/// occupies the centre 60%; every control is edge-anchored. The plant gets the
/// centre, the glass gets the edges.
struct TerrariumScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var glassMorph

    /// The three-beat hook. A judge is walked through the entire thesis in
    /// twenty seconds without reading a paragraph or granting a permission.
    private enum HookStage { case invite, fogged, settled }
    @State private var stage: HookStage = .invite

    // Live pointer velocity from swipes on the terrarium itself.
    @State private var lastDragPoint: CGPoint?
    @State private var lastDragTime: TimeInterval?
    @State private var smoothedSpeed: Double = 0

    var body: some View {
        ZStack {
            TerrariumView()

            // Swiping here IS the demo. The judge is told to swipe fast, and
            // the glass fogs from their own hand — the thesis lands physically.
            Color.clear
                .contentShape(Rectangle())
                .gesture(worldDrag)

            hud
                .allowsHitTesting(true)

            if let ritual = state.activeRitual {
                ritualView(ritual)
                    .zIndex(10)
                    .transition(reduceMotion
                        ? .opacity
                        : .asymmetric(insertion: .scale(scale: 0.86).combined(with: .opacity),
                                      removal: .scale(scale: 1.04).combined(with: .opacity)))
            }

            if let reveal = state.garden.pendingReveal {
                BloomRevealView(reveal: reveal)
                    .zIndex(20)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion
            ? BloomMotion.crossfade(state.motionScale)
            : BloomMotion.morph(state.motionScale),
            value: state.activeRitual)
        .animation(reduceMotion
            ? BloomMotion.crossfade(state.motionScale)
            : BloomMotion.bloom(state.motionScale),
            value: state.garden.pendingReveal)
        .onChange(of: state.engine.windBucket) { _, bucket in
            if stage == .invite, bucket >= 3 { stage = .fogged }
            else if stage == .fogged, bucket <= 1 { stage = .settled }
        }
        // A live region so VoiceOver narrates the world, not just the controls.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(gardenNarration)
        .sheet(isPresented: Binding(get: { state.showLedger },
                                    set: { state.showLedger = $0 })) {
            LedgerScreen().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(get: { state.showFieldGuide },
                                    set: { state.showFieldGuide = $0 })) {
            FieldGuideScreen().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(get: { state.showGuardian },
                                    set: { state.showGuardian = $0 })) {
            GuardianScreen().presentationDetents([.large])
        }
        .sheet(isPresented: Binding(get: { state.showWhy },
                                    set: { state.showWhy = $0 })) {
            WhyThisExistsView().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(get: { state.showReadStub },
                                    set: { state.showReadStub = $0 })) {
            ReadingGlassStubSheet().presentationDetents([.medium])
        }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            if stage == .settled, state.activeRitual == nil {
                RitualDock(namespace: glassMorph)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            PromptBanner(text: promptText)
                .matchedGeometryEffect(id: "hud-prompt", in: glassMorph,
                                       isSource: state.activeRitual == nil)
                .padding(.bottom, 12)
                .transition(.opacity)
            bottomBar
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            HStack(spacing: 10) {
                GlassIconButton(symbol: BloomSymbol.why, label: "why") { state.showWhy = true }
                GlassIconButton(symbol: BloomSymbol.guardian, label: "guardian") { state.showGuardian = true }
            }
            Spacer()
            GlassIconButton(symbol: BloomSymbol.ledger, label: BloomCopy.gardenLedger) {
                state.showLedger = true
            }
        }
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            WindMeter(namespace: glassMorph)
            Spacer()
            VStack(spacing: 7) {
                BreathControl()
                BreathLabel()
            }
        }
    }

    private var promptText: String {
        switch stage {
        case .invite:  return BloomCopy.gardenSwipeFast
        case .fogged:  return BloomCopy.gardenSleepy
        case .settled: return BloomCopy.gardenPrompt
        }
    }

    @ViewBuilder
    private func ritualView(_ kind: RitualKind) -> some View {
        switch kind {
        case .trace: SlowTraceView(namespace: glassMorph)
        case .still: StillWaterView(namespace: glassMorph)
        case .read:  ReadingGlassView(namespace: glassMorph)
        }
    }

    /// What VoiceOver says about the world. Description, never judgement.
    private var gardenNarration: String {
        let plants = state.garden.garden.plants.count
        let sleepy = state.engine.isSleepy
        var s = sleepy ? "The glass is sleepy. " : ""
        s += plants == 0 ? "An empty terrarium. " : "A terrarium with \(plants) plants. "
        s += "Calm \(Int(state.engine.calm * 100)) percent."
        return s
    }

    // MARK: - World gesture

    @MainActor
    private var worldDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let now = Date().timeIntervalSinceReferenceDate
                if let lp = lastDragPoint, let lt = lastDragTime {
                    let dt = max(1e-4, now - lt)
                    let d = hypot(value.location.x - lp.x, value.location.y - lp.y)
                    smoothedSpeed = smoothedSpeed * 0.70 + (d / dt) * 0.30
                }
                lastDragPoint = value.location
                lastDragTime = now
                state.engine.input.isTouching = true
                state.engine.input.pointerSpeed = smoothedSpeed
            }
            .onEnded { _ in
                lastDragPoint = nil
                lastDragTime = nil
                smoothedSpeed = 0
                state.engine.input.isTouching = false
                state.engine.input.pointerSpeed = 0
            }
    }
}

/// Reading Glass arrives with the camera in Step 3. It explains itself rather
/// than pretending to work — a missing button looks broken, a hidden one lies.
struct ReadingGlassStubSheet: View {
    @Environment(AppState.self) private var state
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: BloomSymbol.read)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(.secondary)
            Text(BloomCopy.readStubTitle)
                .font(.bloomTitle)
                .multilineTextAlignment(.center)
            Text(BloomCopy.readStubBody)
                .font(.bloomAdultNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button(BloomCopy.whyClose) { state.showReadStub = false }
                .font(.bloomCaption)
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .padding(28)
        .presentationBackground(.regularMaterial)
    }
}
