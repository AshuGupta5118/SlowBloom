import SwiftUI

// ⚠️ THIS IS THE ONLY FILE THAT TOUCHES `glassEffect`.
// If the Liquid Glass API differs on your Xcode / Swift Playgrounds version,
// you fix it HERE and nowhere else. Fallbacks are in the Step 1 README (§7).

/// Three tiers. Never a fourth.
///  - `wall`    T1: persistent panels. Non-interactive. This is the jar.
///  - `fitting` T2: anything tappable. Always `.interactive()`.
///  - `breath`  T3: transient overlays. Nearly invisible.
enum GlassTier {
    case wall, fitting, breath
}

enum BloomShape {
    static func panel(_ r: CGFloat = 28) -> AnyShape {
        AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }
    static let pill   = AnyShape(Capsule())
    static let circle = AnyShape(Circle())
}

extension View {
    /// Apply Liquid Glass at a given tier.
    /// - Parameter fog: 0…1. Fogs the glass toward `sleepy` — the negative
    ///   state is a property OF the glass, not an overlay on top of it.
    func bloomGlass(_ tier: GlassTier,
                    tint: Color? = nil,
                    shape: AnyShape = BloomShape.pill,
                    fog: Double = 0) -> some View {
        modifier(BloomGlassModifier(tier: tier, tint: tint, shape: shape, fog: fog))
    }

    /// Sleepy double-encoding for Differentiate Without Color: fog also
    /// tightens the corner radius, so the state survives greyscale.
    func bloomPanelRadius(base: CGFloat = 28, fog: Double) -> AnyShape {
        BloomShape.panel(base - CGFloat(min(fog, 1) * 4.0))
    }
}

private struct BloomGlassModifier: ViewModifier {
    let tier: GlassTier
    let tint: Color?
    let shape: AnyShape
    let fog: Double

    func body(content: Content) -> some View {
        content.glassEffect(resolvedGlass, in: shape)
    }

    private var resolvedGlass: Glass {
        var g: Glass = (tier == .breath) ? .clear : .regular
        if let tint {
            g = g.tint(tint)
        } else if fog > 0.06 {
            g = g.tint(Color(red: 0.61, green: 0.63, blue: 0.64).opacity(min(0.55, fog * 0.55)))
        }
        if tier == .fitting { g = g.interactive() }
        return g
    }
}

/// Convenience wrapper so call sites read declaratively.
struct GlassPanel<Content: View>: View {
    let tier: GlassTier
    var fog: Double = 0
    var radius: CGFloat = 28
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .bloomGlass(tier, shape: BloomShape.panel(radius - CGFloat(min(fog, 1) * 4)), fog: fog)
    }
}
