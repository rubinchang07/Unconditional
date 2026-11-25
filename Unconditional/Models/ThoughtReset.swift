import Foundation
import SwiftData

/// A common thought for one of your loops, paired with a gentler perspective.
/// Seeded with starting text, but every perspective is yours to rewrite.
@Model
final class ResetThought {
    var text: String
    var perspective: String
    var sortOrder: Int
    var loop: Loop?

    init(text: String, perspective: String, sortOrder: Int, loop: Loop? = nil) {
        self.text = text
        self.perspective = perspective
        self.sortOrder = sortOrder
        self.loop = loop
    }
}

/// A short message you want to see when things are hard. Your encouragement library.
@Model
final class SavedReminder {
    var text: String
    var createdAt: Date

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}

/// A big-decision thought (like "I should quit SWE") set aside for the weekly review,
/// so decisions get made calmly instead of in the middle of a spiral.
@Model
final class ParkedThought {
    var text: String
    var createdAt: Date
    /// When you looked at it again. nil means it's still waiting for review.
    var reviewedAt: Date?
    /// At review: how urgent it still feels, 0 to 10.
    var urgencyAtReview: Double = 5
    /// At review: what you've learned or enjoyed since parking it.
    var reviewNote: String = ""

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}

/// A small, doable action chosen after a reset or reframe.
/// The follow-up asks whether you *tried* it, never whether it went well.
@Model
final class TinyStep {
    var text: String
    var createdAt: Date
    /// "tried", "letGo", or nil while it's still open.
    var outcome: String?
    /// "Not yet" hides it until this date.
    var snoozedUntil: Date?

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }

    var isOpen: Bool {
        outcome == nil && (snoozedUntil ?? .distantPast) <= .now
    }
}
