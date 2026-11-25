import Foundation
import SwiftData

/// One of the recurring thought patterns, like "the self-worth and failure loop".
///
/// This is a SwiftData `@Model`, not an `enum`, so the loops live in the database
/// and can be renamed, edited, or added to from inside the app later.
@Model
final class Loop {
    var name: String
    /// The belief that keeps the loop running, e.g. "If I struggle or fail, it means I'm inadequate."
    var coreBelief: String
    /// The chain of steps, e.g. "Difficulty → Self-judgment → Shame → Avoidance".
    var pattern: String
    /// Controls the order loops appear in pickers and charts.
    var sortOrder: Int

    /// The other side of `Entry.loop`. `.nullify` means deleting a loop
    /// keeps its entries and just clears their loop.
    @Relationship(deleteRule: .nullify, inverse: \Entry.loop)
    var entries: [Entry] = []

    /// Map links that start or end at this loop. Deleting the loop removes them.
    @Relationship(deleteRule: .cascade, inverse: \MapLink.loopA)
    var linksFrom: [MapLink] = []
    @Relationship(deleteRule: .cascade, inverse: \MapLink.loopB)
    var linksTo: [MapLink] = []

    init(name: String, coreBelief: String, pattern: String, sortOrder: Int) {
        self.name = name
        self.coreBelief = coreBelief
        self.pattern = pattern
        self.sortOrder = sortOrder
    }
}
