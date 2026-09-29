import SwiftUI

@main
struct SlowBloomApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .environment(\.layoutDirection, .leftToRight)
                .tint(BloomPaletteTint.moss)
                // SlowBloom is a desk object. It should not ask for attention.
                .persistentSystemOverlays(.hidden)
        }
    }
}

/// System-tint helper so `.tint()` gets a plain Color, not a WorldColors member.
enum BloomPaletteTint {
    static let moss = Color(red: 0.37, green: 0.55, blue: 0.29)
}

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch state.phase {
            case .sensoryPicker:
                SensoryPickerScreen()
                    .transition(.opacity)
            case .garden:
                TerrariumScreen()
                    .transition(.opacity)
            }
        }
        .animation(BloomMotion.crossfade(state.motionScale), value: state.phase)
        .onAppear { state.start() }
        .onChange(of: scenePhase) { _, next in
            // Pause accumulation on background; resume exactly where it was.
            // Never reset. INV-1 applies to time as well as growth.
            switch next {
            case .active: state.start()
            default:      state.stop(); state.garden.save()
            }
        }
        // One tap exits from anywhere, and it never asks "are you sure?"
        // A child who feels trapped has a tantrum — and preventing tantrums
        // is the entire premise.
        .statusBarHidden(state.activeRitual != nil)
        .preferredColorScheme(nil)
    }
}

#Preview("Garden") {
    RootView()
        .environment({
            let s = AppState()
            s.profile.hasChosen = true
            s.phase = .garden
            s.directorsCut = true
            s.garden.seedForDirectorsCut()
            return s
        }())
}
