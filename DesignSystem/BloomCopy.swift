import Foundation

/// EVERY string in the app lives here, and nowhere else.
///
/// Voice: a patient gardener. Not a coach, not a parent, not a game.
/// SlowBloom never comments on the child — it only ever describes the garden.
///
/// Child-facing rules, enforced by SelfTest:
///   - max 8 words
///   - max 34 characters
///   - Flesch-Kincaid grade <= 3.0
///   - lowercase species names, never ALL CAPS
///   - no exclamation marks, ever
///   - vocabulary: sleepy / foggy / thirsty / quiet / settling
///     NEVER: wither / die / lose / fail
enum BloomCopy {

    // MARK: Onboarding (S1)
    static let pickerTitle      = "How should SlowBloom feel?"
    static let pickerJustShowMe = "just show me"
    static let pickerDone       = "into the garden"

    // MARK: Garden (S2)
    static let gardenPrompt     = "Nothing here grows quickly."
    static let gardenSwipeFast  = "Swipe fast."
    static let gardenBreathe    = "Now breathe."
    static let gardenSleepy     = "The glass got foggy. That's okay."
    static let gardenBreatheCTA = "breathe"
    static let gardenLedger     = "ledger"
    static let gardenWaited     = "It waited for you."

    // MARK: Rituals
    static let traceTitle       = "Trace the vine. Slowly."
    static let traceNoLift      = "Don't lift your finger."
    static let traceDwell       = "hold instead of drawing"
    static let traceSpeed       = "speed"
    static let traceLifts       = "lifts"
    static let traceNoTimer     = "no timer here"

    static let stillTitle       = "Hold still."
    static let stillCup         = "Like a full cup of water."
    static let stillHint        = "Don't touch the glass."

    static let readTitle        = "Point at a book."
    static let readTap          = "Tap the book."
    static let readHold         = "Then let go."

    // MARK: Bloom (S6)
    static func provenanceTrace(_ seconds: Int) -> String {
        "traced slowly for \(seconds) seconds"
    }
    static func provenanceStill(_ seconds: Int) -> String {
        "held still for \(seconds) seconds"
    }
    static func provenanceRead(_ pages: Int) -> String {
        pages == 1 ? "one page of a real book" : "\(pages) pages of a real book"
    }
    static let creatureBorn     = "something hatched"

    // MARK: Ledger (S7) / Field Guide (S8)
    static let ledgerTitle      = "ledger"
    static let ledgerEmpty      = "Nothing has grown yet."
    static let guideTitle       = "field guide"
    static let guideUndiscovered = "not found yet"

    // MARK: Guardian (S9) — adult voice, exempt from the 8-word rule
    static let guardianTitle        = "Guardian"
    static let guardianGatePrompt   = "To continue, solve: 7 + 5 = ?"
    static let guardianGateWrong    = "Not quite. Try again."
    static let guardianPrivacyTitle = "What this app never does"
    static let guardianPrivacy = """
    SlowBloom points only at the rear camera. It never sees a face, never \
    infers gaze, retains no camera frame, and stores no sensor trace. Only \
    aggregate garden state is written, to this device.

    There is no account, no network call, and no analytics. Nothing leaves \
    this iPad.
    """
    static let guardianCalmTitle    = "Calm minutes"
    static let guardianSensory      = "Sensory profile"
    static let guardianDirectors    = "Director's Cut"
    static let guardianDirectorsNote = "Seeds the garden, shortens every ritual to about 20 seconds, and disables all permission prompts. Enabled automatically on first launch so a visitor can understand the app in three minutes."
    static let guardianSelfTest     = "Run self-test"

    // MARK: Why this exists
    static let whyTitle = "Why this exists"
    static let whyBody = """
    Short-form video trains the hand to flick and the eye to move on. A \
    screen-time lock answers that with a wall, and a wall produces a \
    tantrum, not patience.

    SlowBloom answers it with weather. Nothing here grows unless you move \
    slowly, and nothing is ever taken away.
    """
    static let whyForestTitle = "How this differs from a focus timer"
    static let whyForest = """
    Focus timers measure absence: did you leave the app? If you did, your \
    tree dies.

    SlowBloom measures the quality of movement: how did you move while you \
    stayed? Growth here never decreases. There is no timer, no streak, and \
    nothing to lose.
    """
    static let whyClose = "back to the garden"

    // MARK: Reading Glass placeholder (Step 1)
    static let readStubTitle = "This ritual needs the camera."
    static let readStubBody  = "It arrives in Step 3, with ARKit and Vision. The other two rituals work right now."

    // MARK: - The audit list
    /// Every CHILD-FACING string. `SelfTest` fails if any exceeds 8 words or
    /// 34 characters, or contains an exclamation mark or a banned word.
    static let childFacing: [String] = [
        pickerTitle, pickerJustShowMe, pickerDone,
        gardenPrompt, gardenSwipeFast, gardenBreathe, gardenSleepy,
        gardenBreatheCTA, gardenLedger, gardenWaited,
        traceTitle, traceNoLift, traceDwell, traceSpeed, traceLifts, traceNoTimer,
        stillTitle, stillCup, stillHint,
        readTitle, readTap, readHold,
        creatureBorn, ledgerTitle, ledgerEmpty, guideTitle, guideUndiscovered,
        provenanceTrace(61), provenanceStill(90), provenanceRead(1), provenanceRead(4),
        whyClose
    ]

    /// Words that must never appear in child-facing copy.
    static let bannedWords: Set<String> = [
        "wither", "withered", "die", "died", "dead", "lose", "lost",
        "fail", "failed", "wrong", "bad", "streak", "score", "level",
        "great job", "awesome", "oops", "try again", "focus", "hurry"
    ]
}
