import Foundation
import SwiftUI

/// Accessibility is the FIRST SCREEN, not a settings menu buried three levels
/// down. The model for this is Pine Hearts (ADA 2026, Inclusivity), which
/// "clearly communicates its inclusivity options even before play begins".
///
/// Four chips, one screen, eight seconds. All reversible from anywhere via a
/// long-press on the terrarium.
struct SensoryProfile: Codable, Equatable {

    enum Movement: String, Codable, CaseIterable, Identifiable {
        case lively, gentle, still
        var id: String { rawValue }
        var label: String {
            switch self { case .lively: "Lively"; case .gentle: "Gentle"; case .still: "Still" }
        }
    }
    enum Sound: String, Codable, CaseIterable, Identifiable {
        case full, quiet, off
        var id: String { rawValue }
        var label: String {
            switch self { case .full: "Full"; case .quiet: "Quiet"; case .off: "Off" }
        }
        /// 0…1 multiplier on every audio layer.
        var gain: Double {
            switch self { case .full: 1.0; case .quiet: 0.35; case .off: 0.0 }
        }
    }
    enum Touch: String, Codable, CaseIterable, Identifiable {
        case full, gentle, off
        var id: String { rawValue }
        var label: String {
            switch self { case .full: "Full"; case .gentle: "Gentle"; case .off: "Off" }
        }
        /// 0…1 multiplier on haptic intensity. Default is 60%, not 100%.
        var intensity: Double {
            switch self { case .full: 0.60; case .gentle: 0.25; case .off: 0.0 }
        }
    }
    enum Reading: String, Codable, CaseIterable, Identifiable {
        case pictures, words, spoken
        var id: String { rawValue }
        var label: String {
            switch self { case .pictures: "Pictures"; case .words: "Words"; case .spoken: "Read aloud" }
        }
    }

    var movement: Movement = .gentle
    var sound: Sound = .quiet
    var touch: Touch = .gentle
    var reading: Reading = .words

    /// True once the child has answered S1. Until then the picker shows.
    var hasChosen: Bool = false

    // MARK: Derived

    /// Particle systems are disabled entirely at `.still`, and under Reduce Motion.
    func particlesEnabled(reduceMotion: Bool) -> Bool {
        reduceMotion ? false : (movement != .still)
    }

    /// Combined with system Reduce Motion: sensory reduction is ONE setting.
    func hapticScale(reduceMotion: Bool) -> Double {
        reduceMotion ? touch.intensity * 0.5 : touch.intensity
    }

    static let `default` = SensoryProfile()
}

// MARK: - Persistence
enum SensoryProfileStore {
    private static let key = "slowbloom.sensoryProfile.v1"

    static func load() -> SensoryProfile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(SensoryProfile.self, from: data)
        else { return .default }
        return p
    }

    static func save(_ p: SensoryProfile) {
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
