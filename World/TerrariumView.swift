import SwiftUI

/// The whole world: room, contact shadow, jar contents, glass, condensation.
///
/// This is the FALLBACK scene — the one that renders with no camera, no ARKit
/// and no permissions. It is a designed composition, not an error state.
/// Step 4 layers the ARKit-anchored RealityKit version on top of it and this
/// becomes what shows when no plane is found. It must always look intentional.
struct TerrariumView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoomBackground(goldenHour: state.goldenHour, dark: scheme == .dark)

            GeometryReader { proxy in
                let layout = JarLayout.make(in: proxy.size)

                ZStack {
                    // Contact shadow sells the illusion more than any texture.
                    ContactShadow(rect: layout.jar)

                    TerrariumCanvas()
                    JarOverlay()
                    Condensation()
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct RoomBackground: View {
    let goldenHour: Bool
    let dark: Bool

    var body: some View {
        let top: Color = goldenHour
            ? Color(red: 0.24, green: 0.19, blue: 0.16)
            : (dark ? Color(red: 0.10, green: 0.11, blue: 0.12) : Color(red: 0.93, green: 0.93, blue: 0.94))
        let bottom: Color = goldenHour
            ? Color(red: 0.13, green: 0.10, blue: 0.09)
            : (dark ? Color(red: 0.05, green: 0.06, blue: 0.07) : Color(red: 0.84, green: 0.84, blue: 0.86))
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

private struct ContactShadow: View {
    let rect: CGRect
    var body: some View {
        Ellipse()
            .fill(.radialGradient(
                Gradient(colors: [Color.black.opacity(0.52), Color.black.opacity(0)]),
                center: .center, startRadius: 1, endRadius: rect.width * 0.52))
            .frame(width: rect.width * 1.02, height: rect.height * 0.14)
            .position(x: rect.midX, y: rect.maxY - rect.height * 0.01)
            .blur(radius: 6)
            .accessibilityHidden(true)
    }
}
