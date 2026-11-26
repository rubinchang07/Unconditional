import Foundation
import SwiftData

/// "One step at a time": something that feels daunting, and the steps you've taken toward it.
///
/// On purpose there's no target, no percentage, and no finish line. A path only
/// records steps you took, each one counting the same however it turned out,
/// so it can't become one more thing to fall short of.
@Model
final class StepPath {
    var title: String = ""
    var createdAt: Date = Date.now
    /// Set aside for now. Not given up on, not failed: just resting.
    var isResting: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Footstep.path)
    var steps: [Footstep] = []

    init(title: String, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
    }

    /// Oldest first, the order you walked them.
    var walked: [Footstep] { steps.sorted { $0.createdAt < $1.createdAt } }
}

/// One step you took. Only what you did, never whether it worked.
@Model
final class Footstep {
    var text: String = ""
    var createdAt: Date = Date.now
    var path: StepPath?

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }

    /// Older prints soften, like sand smoothing over, but never disappear.
    /// 1 for today, easing to 0.55 after about a month.
    static func softness(age days: Double) -> Double {
        1 - 0.45 * min(max(days, 0) / 30, 1)
    }
}
