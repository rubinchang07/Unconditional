import Foundation
import SwiftData

/// Something that matters to you regardless of outcomes, like curiosity or kindness.
///
/// This is the heart of unconditional self-worth: you can live a value today,
/// whether or not the job offer, the relationship, or the timeline has arrived.
/// (Named `PersonalValue` because `Value` is too generic a name in Swift.)
@Model
final class PersonalValue {
    var name: String
    /// What living this value looks like for you, in your words.
    var meaning: String
    /// How much you lived it lately, 0 to 10. Not a grade: a check-in.
    var livedLately: Double = 5
    var createdAt: Date

    init(name: String, meaning: String = "", createdAt: Date = .now) {
        self.name = name
        self.meaning = meaning
        self.createdAt = createdAt
    }

    /// Starting ideas. You pick the ones that feel like yours, or write your own.
    static let suggestions = [
        "Curiosity", "Kindness", "Honesty", "Growth", "Courage", "Creativity",
        "Connection", "Showing up", "Health", "Family", "Learning", "Patience",
        "Humor", "Independence", "Craft", "Generosity",
    ]
}
