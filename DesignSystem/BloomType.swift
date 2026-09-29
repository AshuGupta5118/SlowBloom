import SwiftUI

/// TWO faces only. SF Rounded for everything child-facing, SF Pro for the
/// Guardian view. Never a third-party or novelty font — that single choice is
/// what separates "Apple made this for kids" from "a student made this".
///
/// Semantic styles only. Never a hardcoded point size. That is what makes
/// Dynamic Type to AX5 work for free.
extension Font {
    /// Species name on discovery. One per screen, ever.
    static let bloomHero      = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Ritual titles.
    static let bloomTitle     = Font.system(.title2, design: .rounded).weight(.semibold)
    /// The one instruction line. Max 8 words.
    static let bloomPrompt    = Font.system(.title3, design: .rounded)
    /// Numbers. Always pair with `.monospacedDigit()`.
    static let bloomMetric    = Font.system(.body, design: .rounded).weight(.medium)
    /// Big numbers (Wind Meter readout).
    static let bloomMetricBig = Font.system(.title3, design: .rounded).weight(.semibold)
    /// Secondary labels.
    static let bloomCaption   = Font.system(.footnote, design: .rounded)
    /// Guardian view only — signals "this part is for the grown-up".
    static let bloomAdult     = Font.system(.body)
    static let bloomAdultHead = Font.system(.title2).weight(.semibold)
    static let bloomAdultNote = Font.system(.footnote)
}
