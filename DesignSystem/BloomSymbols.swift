import SwiftUI

/// SF Symbols only. No custom iconography in the chrome layer.
/// If any name below fails to resolve on your Xcode version, swap it for a
/// neighbouring symbol in the SF Symbols app — nothing else depends on it.
enum BloomSymbol {
    // World
    static let leaf        = "leaf.fill"
    static let seedling    = "camera.macro"          // closest native "sprout" glyph
    static let drop        = "drop.fill"
    static let tortoise    = "tortoise.fill"          // the creature: slow by nature
    static let wind        = "wind"
    static let sparkles    = "sparkles"
    static let moonStars   = "moon.stars.fill"

    // Rituals
    static let trace       = "hand.draw.fill"
    static let still       = "drop.fill"
    static let read        = "book.closed.fill"

    // Chrome
    static let breathe     = "figure.mind.and.body"
    static let ledger      = "list.bullet"
    static let guide       = "hexagon.fill"
    static let guardian    = "gearshape.fill"
    static let why         = "questionmark.circle"
    static let close       = "xmark"
    static let eyeOff      = "eye.slash.fill"
    static let check       = "checkmark.circle.fill"
    static let warn        = "xmark.circle.fill"

    // Sensory picker
    static let movement    = "wind"
    static let sound       = "waveform"
    static let touch       = "hand.tap.fill"
    static let reading     = "textformat.size"
}
