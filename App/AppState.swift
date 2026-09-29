import Foundation
import Observation
import SwiftUI
import UIKit

/// Root state. One instance, injected through the environment.
///
/// It owns the frame loop, which is the ONLY clock in the app. Nothing uses a
/// Timer and nothing uses withAnimation inside a gesture's onEnded. Growth,
/// sleepiness, wind, sway and ripples are all continuous functions of this
/// loop — which is what makes the terrarium feel alive rather than animated.
@MainActor
@Observable
final class AppState {

    enum Phase: Equatable { case sensoryPicker, garden }

    // MARK: Dependencies
    let engine: AttentionEngine
    let garden: GardenStore

    // MARK: Navigation
    var phase: Phase = .sensoryPicker
    var activeRitual: RitualKind?
    var showLedger = false
    var showFieldGuide = false
    var showGuardian = false
    var showWhy = false
    /// Reading Glass arrives with the camera in Step 3. Rather than hide the
    /// chip — which would look like a broken button — it explains itself.
    var showReadStub = false

    // MARK: Preferences
    var profile: SensoryProfile {
        didSet { SensoryProfileStore.save(profile) }
    }
    /// Seeds the garden and shortens every ritual to ~20 s.
    /// ON for the very first launch, because for a visitor it always is.
    var directorsCut: Bool
    /// Derived from the clock; overridable from the Guardian view.
    var calmModeOverride: Bool? = nil

    // MARK: Breath control (INV-2: one slow action reverses every negative state)
    var isBreathing = false
    var breathProgress: Double = 0
    private let breathDuration: Double = 3.0

    // MARK: Ritual progress (written by the ritual views)
    var ritualElapsed: Double = 0
    /// Seconds spent actually meeting the ritual's condition. Elapsed time is
    /// NOT progress: a fidget pauses accumulation and nothing is taken away.
    var ritualAccumulated: Double = 0
    /// The pollen spark's position along the vine, 0…1. Advances only while
    /// the finger is down, at exactly the target pace — the child's job is to
    /// FOLLOW it, which works for a pre-reader.
    var traceGuide: Double = 0
    var ritualDeliberateness: Double = 0.5
    var ritualLifts: Int = 0
    var ritualPageTurns: Int = 0

    private var loop: Task<Void, Never>?
    private var lastTick: TimeInterval = Date().timeIntervalSinceReferenceDate

    init() {
        let loaded = SensoryProfileStore.load()
        self.profile = loaded
        self.engine = AttentionEngine()
        self.garden = GardenStore()
        self.directorsCut = !loaded.hasChosen
        if self.directorsCut { self.garden.seedForDirectorsCut() }
        self.phase = loaded.hasChosen ? .garden : .sensoryPicker
    }

    // MARK: - Derived

    var goldenHour: Bool {
        if let calmModeOverride { return calmModeOverride }
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 18 || h < 6
    }

    var motionScale: Double {
        BloomMotion.durationScale(profile: profile, goldenHour: goldenHour)
    }

    /// Reduce Motion is read per-view from the environment; this is the
    /// non-environment copy for places that need it outside a View body.
    var reduceMotionFallback: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    func bounce(reduceMotion: Bool) -> Double {
        BloomMotion.bounceScale(reduceMotion: reduceMotion, profile: profile)
    }

    var ritualTarget: Double {
        (activeRitual ?? .trace).target(directorsCut: directorsCut)
    }

    // MARK: - The clock

    func start() {
        guard loop == nil else { return }
        lastTick = Date().timeIntervalSinceReferenceDate
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self else { return }
                let now = Date().timeIntervalSinceReferenceDate
                // Clamp: a stalled frame must not teleport growth forward.
                let dt = min(0.1, max(0.001, now - self.lastTick))
                self.lastTick = now

                self.engine.input.ritual = self.activeRitual
                self.engine.tick(dt: dt)

                if let ritual = self.activeRitual {
                    self.ritualElapsed += dt
                    switch ritual {
                    case .still:
                        if self.engine.stillness > 0.75 { self.ritualAccumulated += dt }
                    case .read:
                        if (self.engine.input.focusQuality ?? 0) > 0.60 { self.ritualAccumulated += dt }
                    case .trace:
                        // Completion is path-based (decided by SlowTraceView);
                        // here we only advance the guide at the target pace.
                        if self.engine.input.isTouching {
                            self.traceGuide = min(1, self.traceGuide + dt / max(6, self.ritualTarget))
                        }
                    }
                    // Still Water and Reading Glass complete on accumulated time.
                    if ritual != .trace, self.ritualAccumulated >= self.ritualTarget {
                        self.endRitual(completed: true)
                    }
                }

                self.garden.advance(dt: dt,
                                    calm: self.engine.calm,
                                    wind: self.engine.wind)

                if self.isBreathing {
                    self.breathProgress = min(1, self.breathProgress + dt / self.breathDuration)
                    self.engine.breathe(dt: dt, progress: self.breathProgress)
                    if self.breathProgress >= 1 {
                        self.isBreathing = false
                        // Hold at 1 so the ring stays full for the release animation.
                    }
                } else if self.breathProgress > 0 {
                    self.breathProgress = max(0, self.breathProgress - dt / 0.6)
                }
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    // MARK: - Intents

    func finishOnboarding() {
        profile.hasChosen = true
        SensoryProfileStore.save(profile)
        withAnimation(BloomMotion.morph(motionScale)) { phase = .garden }
    }

    func beginRitual(_ kind: RitualKind) {
        ritualElapsed = 0
        ritualAccumulated = 0
        traceGuide = 0
        ritualDeliberateness = 0.5
        ritualLifts = 0
        ritualPageTurns = 0
        engine.reset()
        withAnimation(BloomMotion.morph(motionScale)) { activeRitual = kind }
    }

    func endRitual(completed: Bool) {
        guard let kind = activeRitual else { return }
        if completed {
            garden.completeRitual(kind,
                                  seconds: ritualElapsed,
                                  deliberateness: ritualDeliberateness,
                                  lifts: ritualLifts,
                                  pageTurns: ritualPageTurns)
        }
        withAnimation(BloomMotion.morph(motionScale)) { activeRitual = nil }
        engine.input = .idle
        ritualElapsed = 0
    }

    func beginBreath() {
        guard !isBreathing else { return }
        isBreathing = true
        breathProgress = 0
    }

    func endBreath() { isBreathing = false }
}
