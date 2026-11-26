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

    /// Your footprints, oldest first, the order you walked them. Tides aren't steps.
    var walked: [Footstep] { everything.filter { !$0.isTide } }

    /// Hard days you marked, oldest first.
    var tides: [Footstep] { everything.filter(\.isTide) }

    /// Prints and tides together, oldest first, as they happened.
    var everything: [Footstep] { steps.sorted { $0.createdAt < $1.createdAt } }
}

/// One step you took. Only what you did, never whether it worked.
///
/// Or, when `isTide` is set, a hard day: the tide came in over the sand and went
/// back out. A tide never erases a print and is never drawn as a step backward.
/// It just shows that the walk included hard days, which every walk does.
@Model
final class Footstep {
    var text: String = ""
    var createdAt: Date = Date.now
    var path: StepPath?
    /// A hard day rather than a step.
    var isTide: Bool = false
    /// How hard it felt, 0 a little to 1 very. Only for tides.
    var heaviness: Double = 0
    /// "Anything you learned?" after the tide went out. Optional.
    var learned: String = ""

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }

    /// Older prints soften, like sand smoothing over, but never disappear.
    /// 1 for today, easing to 0.55 after about a month.
    static func softness(age days: Double) -> Double {
        1 - 0.45 * min(max(days, 0) / 30, 1)
    }

    /// How high the water rises for a hard day, as a share of the screen.
    /// Even "very hard" leaves the top of the path, and the horizon, in view.
    static func tideReach(heaviness: Double) -> Double {
        0.18 + 0.42 * min(max(heaviness, 0), 1)
    }
}
