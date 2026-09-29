import SwiftUI
import UIKit

// MARK: - Chrome
// The chrome layer uses SYSTEM SEMANTIC COLOURS ONLY. Not inventing a UI
// palette is precisely what makes this look Apple-made. Never reference
// BloomPalette.* from a HUD component.

// MARK: - World
/// The world palette, resolved for a specific appearance.
///
/// Resolving eagerly (rather than using dynamic UIColors) is deliberate:
/// SwiftUI `Canvas` cannot resolve trait-dependent colours, and we need to
/// blend colours numerically for the sleepy/droop state. So the view layer
/// reads `colorScheme` + `accessibilityIncreasedContrast` and asks for a
/// concrete `WorldColors` once.
struct WorldColors: Equatable {
    var moss: Color
    var fern: Color
    var bloom: Color
    var pollen: Color
    var water: Color
    var bark: Color
    var dusk: Color
    /// The negative state. Grey-green and soft.
    var sleepy: Color
    var soil: Color
    var soilDeep: Color
    var glassEdge: Color
    var highlight: Color

    static func make(dark: Bool, highContrast: Bool = false) -> WorldColors {
        if dark {
            return WorldColors(
                moss: hex(0x8FBF6A), fern: hex(0x63C39A), bloom: hex(0xF2B8D6),
                pollen: hex(0xFFD873), water: hex(0x9FD0EE), bark: hex(0xB08A67),
                dusk: hex(0xA8A6D0), sleepy: hex(0x6E7378),
                soil: hex(0x3A2E24), soilDeep: hex(0x241C15),
                glassEdge: Color.white.opacity(highContrast ? 0.65 : 0.30),
                highlight: Color.white.opacity(highContrast ? 0.30 : 0.13))
        }
        return WorldColors(
            moss: hex(0x5E8C4A), fern: hex(0x3F7A5E), bloom: hex(0xE8A0C4),
            pollen: hex(0xF2C14E), water: hex(0x7FB6D9), bark: hex(0x8A6A4F),
            dusk: hex(0x6B6A8C), sleepy: hex(0x9AA0A6),
            soil: hex(0x4A3A2C), soilDeep: hex(0x2C2119),
            glassEdge: Color.white.opacity(highContrast ? 0.85 : 0.45),
            highlight: Color.white.opacity(highContrast ? 0.38 : 0.18))
    }

    /// Golden Hour: everything drifts toward dusk/pollen.
    func goldenHour() -> WorldColors {
        var c = self
        c.moss = c.moss.mixed(with: dusk, 0.28)
        c.fern = c.fern.mixed(with: dusk, 0.24)
        c.water = c.water.mixed(with: pollen, 0.18)
        c.highlight = Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.20)
        return c
    }

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255.0,
              green: Double((v >> 8) & 0xFF) / 255.0,
              blue: Double(v & 0xFF) / 255.0)
    }
}

// MARK: - Mixing
extension Color {
    /// Numerical blend between two colours. Only reliable for colours built
    /// from explicit RGB (which every WorldColors member is). Returns `self`
    /// unchanged if the components can't be resolved.
    func mixed(with other: Color, _ t: Double) -> Color {
        let k = CGFloat(min(max(t, 0), 1))
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        guard a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa),
              b.getRed(&br, green: &bg, blue: &bb, alpha: &ba) else { return self }
        return Color(red: ar + (br - ar) * k,
                     green: ag + (bg - ag) * k,
                     blue: ab + (bb - ab) * k,
                     opacity: aa + (ba - aa) * k)
    }

    /// Desaturate toward grey. Used by the sleepy state.
    func desaturated(_ amount: Double) -> Color {
        let grey = Color(red: 0.55, green: 0.57, blue: 0.58)
        return mixed(with: grey, amount)
    }
}
