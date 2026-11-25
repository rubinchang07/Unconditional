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

    /// Starting thoughts for Thought Reset, keyed by loop name. Perspectives avoid
    /// absolutes on purpose: they offer another angle, not a verdict.
    static let resetThoughts: [String: [(thought: String, perspective: String)]] = [
        "Self-worth and failure": [
            ("I don't think I'm capable.",
             "Struggling with something hard is what learning feels like from the inside. It shows where you are right now, not what you're worth."),
            ("I should understand this by now.",
             "There's no deadline on understanding. Confusion is often the step right before something clicks."),
        ],
        "Career indecision": [
            ("I think I've chosen the wrong career.",
             "You don't have to settle your whole career today. Doubt is worth examining, but it doesn't demand an immediate pivot. Could this wait for your weekly review?"),
            ("Something else would feel more certain.",
             "Every path has uncertainty. This one's is just the one you can see up close. The goal can be trade-offs you can live with, rather than total confidence."),
        ],
        "Falling behind": [
            ("I'm falling behind everyone else.",
             "You're comparing your behind-the-scenes with other people's highlights. Lives don't run on one shared timeline."),
            ("I'm running out of time.",
             "Urgency makes every choice feel huge. Most of what matters gets built slowly, one ordinary day at a time."),
        ],
        "Fear of wasted effort": [
            ("What if this is all for nothing?",
             "Effort is rarely wasted. Skills, habits, and self-knowledge carry over, even when the plan changes."),
            ("AI might make this pointless.",
             "Nobody knows exactly how this will play out. Learning how to learn, and showing up steadily, stays useful either way."),
        ],
        "Independence and romance": [
            ("I'm not good enough for a relationship.",
             "Being worth loving doesn't wait on a job title. The people who matter will care about who you are, not where you are on a timeline."),
            ("My life is on hold until my career is sorted.",
             "Some parts of your life can grow now, alongside your career. You don't have to finish one chapter before starting another."),
        ],
    ]

    /// Only seeds what's missing, so your edits are never overwritten.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let loopCount = (try? context.fetchCount(FetchDescriptor<Loop>())) ?? 0
        if loopCount == 0 {
            for (index, item) in defaults.enumerated() {
                context.insert(Loop(name: item.name, coreBelief: item.coreBelief, pattern: item.pattern, sortOrder: index))
            }
        }

        // Thought Reset arrived in a later version, so it seeds separately.
        let thoughtCount = (try? context.fetchCount(FetchDescriptor<ResetThought>())) ?? 0
        if thoughtCount == 0 {
            let loops = (try? context.fetch(FetchDescriptor<Loop>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
            var order = 0
            for loop in loops {
                // Match by original position, so a loop you renamed still gets its thoughts.
                let key = defaults.indices.contains(loop.sortOrder) ? defaults[loop.sortOrder].name : loop.name
                for item in resetThoughts[key] ?? [] {
                    let thought = ResetThought(text: item.thought, perspective: item.perspective, sortOrder: order)
                    context.insert(thought)
                    thought.loop = loop
                    order += 1
                }
            }
        }
        try? context.save()
    }
}
