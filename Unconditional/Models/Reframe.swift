import Foundation
import SwiftData

/// A CBT-style thought record attached to one `Entry` (one-to-one).
@Model
final class Reframe {
    /// What happened? e.g. "Couldn't solve a LeetCode medium in 40 minutes."
    var trigger: String
    /// What did it seem to prove? Pre-filled from the loop's core belief.
    var coreBelief: String
    /// Facts that seem to support the belief.
    /// Default values let SwiftData add these fields to existing reframes automatically.
    var evidenceFor: String = ""
    /// Facts that don't fit the belief.
    var evidenceAgainst: String = ""
    /// A kinder, more accurate read of the same facts.
    var kinderRead: String
    /// One small, doable next step.
    var smallStep: String
    var createdAt: Date

    // Before-and-after ratings. Feelings come in degrees, so these are
    // sliders, not yes/no. Over time they show whether reframing helps.
    /// How distressed you felt, 0 (calm) to 10 (overwhelmed), before the reframe.
    var distressBefore: Double = 5
    var distressAfter: Double = 5
    /// How much you believed the core belief, 0 to 100%, before and after.
    var beliefBefore: Double = 70
    var beliefAfter: Double = 70
    /// After the reframe: how true the kinder thought seems in your head, 0 to 1.
    /// Shown beside how light it feels (from `distressAfter`), as two waves. -1 when not asked.
    var headTrue: Double = -1
    /// How heavy it looks once you step back and see it logically, 0 heavy to 1 light:
    /// the same scale as the heart, so head and heart can be compared fairly
    /// (both heavy is in tune, too). -1 when not asked. Replaces `headTrue`.
    var headLight: Double = -1

    /// Whether this reframe compares head and heart (newer) rather than before and after.
    var hasHeadAndHeart: Bool { headLight >= 0 || headTrue >= 0 }

    /// The head's answer, 0 heavy to 1 light (older reframes asked how true it seemed instead).
    var headValue: Double { headLight >= 0 ? headLight : headTrue }
    /// The heart's answer on the same 0 heavy to 1 light scale.
    var heartValue: Double { 1 - distressBefore / 10 }

    /// A second look a few days later: head and heart again, 0 heavy to 1 light.
    /// The first answers are never changed, so you can see if they've moved. -1 when not yet asked.
    var laterHead: Double = -1
    var laterHeart: Double = -1
    var laterAt: Date?

    var hasLater: Bool { laterHead >= 0 && laterHeart >= 0 }

    /// Days before a reframe is offered for a second look: long enough for things to settle.
    static let revisitAfterDays = 3.0

    /// Whether it's been long enough to look again.
    func canRevisit(now: Date = .now) -> Bool {
        hasHeadAndHeart && now.timeIntervalSince(createdAt) >= Self.revisitAfterDays * 86_400
    }

    var entry: Entry?

    init(trigger: String = "", coreBelief: String = "", kinderRead: String = "", smallStep: String = "", createdAt: Date = .now) {
        self.trigger = trigger
        self.coreBelief = coreBelief
        self.kinderRead = kinderRead
        self.smallStep = smallStep
        self.createdAt = createdAt
    }
}
