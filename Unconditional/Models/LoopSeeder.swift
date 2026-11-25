import Foundation
import SwiftData

/// Inserts the five starting loops the first time the app runs.
enum LoopSeeder {
    static let defaults: [(name: String, pattern: String, coreBelief: String)] = [
        ("Self-worth and failure",
         "Difficulty → Self-judgment → Shame → Avoidance → More self-doubt",
         "If I struggle or fail, it means I'm inadequate."),
        ("Career indecision",
         "Commitment → Doubt → Idealizing alternatives → Pivoting → Renewed doubt",
         "If I make the right decision, I should feel confident about it."),
        ("Falling behind",
         "Comparison → Urgency → Overwhelm → Inaction → Further comparison",
         "I'm running out of time to become the person I should already be."),
        ("Fear of wasted effort",
         "Uncertain payoff → Hesitation → Less experience → Less confidence → Greater uncertainty",
         "I need to know my investment will pay off before I make it."),
        ("Independence and romance",
         "Career insecurity → Fear of limited independence or romance → Greater career pressure → More anxiety",
         "Until I'm professionally established, I can't fully build the life I want."),
    ]

    /// Only seeds when the store has no loops, so your edits are never overwritten.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Loop>())) ?? 0
        guard count == 0 else { return }
        for (index, item) in defaults.enumerated() {
            context.insert(Loop(name: item.name, coreBelief: item.coreBelief, pattern: item.pattern, sortOrder: index))
        }
        try? context.save()
    }
}
