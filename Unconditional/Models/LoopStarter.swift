import Foundation
import SwiftData

/// General loops to start from, so anyone can find theirs. You pick the ones
/// that fit, rename them, or write your own.
struct LoopStarter: Identifiable, Hashable {
    let name: String
    let coreBelief: String
    let thought: String
    let perspective: String
    var id: String { name }

    static let all: [LoopStarter] = [
        LoopStarter(name: "Not good enough",
                    coreBelief: "I have to achieve things to be worth something.",
                    thought: "I'm not good enough.",
                    perspective: "Struggling shows where you are right now, not what you're worth. Your worth isn't a grade you have to keep earning."),
        LoopStarter(name: "Comparing myself",
                    coreBelief: "Other people are further ahead, so I'm behind.",
                    thought: "Everyone is ahead of me.",
                    perspective: "You're comparing your behind-the-scenes with other people's highlights. Lives don't run on one shared timeline."),
        LoopStarter(name: "Worrying about the future",
                    coreBelief: "If I can't be sure it'll be okay, it won't be.",
                    thought: "What if it all goes wrong?",
                    perspective: "Worry feels like preparing, but it's mostly rehearsing. You can meet what actually happens when it happens."),
        LoopStarter(name: "People-pleasing",
                    coreBelief: "If someone is upset with me, I must have done something wrong.",
                    thought: "They must be annoyed with me.",
                    perspective: "You can't know that for sure. Other people's moods are about many things, and most of them aren't you."),
        LoopStarter(name: "Overthinking decisions",
                    coreBelief: "There's one right choice, and I have to find it.",
                    thought: "What if I choose wrong?",
                    perspective: "Most choices can be adjusted later. A good-enough decision you can live with beats a perfect one you never make."),
        LoopStarter(name: "Wasted effort",
                    coreBelief: "If it might not pay off, it isn't worth trying.",
                    thought: "What if this is all for nothing?",
                    perspective: "Effort is rarely wasted. Skills, habits, and self-knowledge carry over, even when the plan changes."),
        LoopStarter(name: "Love and belonging",
                    coreBelief: "I won't be lovable until my life is sorted.",
                    thought: "Nobody would want me like this.",
                    perspective: "Being worth loving doesn't wait on a milestone. The people who matter care about who you are, not where you are on a timeline."),
    ]

    /// Adds loops for the chosen starters (and any names you wrote yourself)
    /// after the loops you already have. Starters bring one Thought Reset each.
    @MainActor
    static func add(starters: [LoopStarter], custom: [String], to context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        var taken = Set(existing.map { $0.name.lowercased() })
        var order = (existing.map(\.sortOrder).max() ?? -1) + 1
        let thoughtOrder = ((try? context.fetchCount(FetchDescriptor<ResetThought>())) ?? 0)

        let ordered = starters.sorted { a, b in
            (all.firstIndex(of: a) ?? 0) < (all.firstIndex(of: b) ?? 0)
        }
        for (offset, starter) in ordered.enumerated() where !taken.contains(starter.name.lowercased()) {
            let loop = Loop(name: starter.name, coreBelief: starter.coreBelief, pattern: "", sortOrder: order)
            context.insert(loop)
            let thought = ResetThought(text: starter.thought, perspective: starter.perspective, sortOrder: thoughtOrder + offset)
            context.insert(thought)
            thought.loop = loop
            taken.insert(starter.name.lowercased())
            order += 1
        }
        for name in custom {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !taken.contains(trimmed.lowercased()) else { continue }
            context.insert(Loop(name: trimmed, coreBelief: "", pattern: "", sortOrder: order))
            taken.insert(trimmed.lowercased())
            order += 1
        }
        try? context.save()
    }
}
