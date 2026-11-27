import NaturalLanguage

/// Feeling words grouped by what a word is about, so Words can offer something
/// specific to the word you typed rather than only general feelings. "Failure"
/// slid heavier offers "not good enough"; "job" slid heavier offers "stuck in place".
/// Each theme has a heavier and a lighter side, and the lighter side is never
/// written as the correct answer, just another honest way it can feel.
struct WordTheme {
    let name: String
    /// Words (or the start of words) that mean you're talking about this theme.
    let triggers: [String]
    let heavy: [String]
    let light: [String]
}

enum WordThemes {
    static let all: [WordTheme] = [
        WordTheme(name: "failure",
                  triggers: ["fail", "mistake", "messed", "screwed", "flop", "wrong", "lose", "loser", "lost"],
                  heavy: ["not good enough", "like a fraud", "exposed", "disappointed in myself", "inadequate",
                          "embarrassed", "like I let people down", "replaying it"],
                  light: ["still learning", "allowed to try again", "human", "brave for trying",
                          "more than one outcome", "it was one try", "growing from it", "gentler with myself"]),
        WordTheme(name: "work",
                  triggers: ["job", "work", "career", "boss", "office", "intern", "interview", "resume", "applic"],
                  heavy: ["stuck in place", "underqualified", "overlooked", "burnt out", "replaceable",
                          "behind my peers", "dreading monday", "unsure of my path"],
                  light: ["capable", "curious about what's next", "proud of my work", "valued",
                          "finding my direction", "competent", "open to options", "useful"]),
        WordTheme(name: "school",
                  triggers: ["school", "class", "exam", "test", "grade", "study", "homework", "college", "essay", "gpa", "lecture"],
                  heavy: ["unprepared", "stupid", "behind in class", "pressure to be perfect", "cramming",
                          "scared of the grade", "slow", "lost in the material"],
                  light: ["prepared", "understanding it", "proud of the effort", "curious", "it clicked",
                          "a grade isn't me", "steady progress", "done for now"]),
        WordTheme(name: "the future",
                  triggers: ["future", "behind", "late", "time", "age", "plan", "next", "direction", "path"],
                  heavy: ["running out of time", "behind everyone", "directionless", "scared of wasting years",
                          "frozen by choices", "like it's too late", "uncertain", "restless about it"],
                  light: ["on my own timeline", "open", "early enough", "curious about it", "trusting the process",
                          "one step is enough", "unhurried", "hopeful"]),
        WordTheme(name: "wasted effort",
                  triggers: ["waste", "pointless", "effort", "for nothing"],
                  heavy: ["like it was for nothing", "regretful", "drained for no reason", "cheated",
                          "second-guessing it all", "foolish"],
                  light: ["it still taught me something", "not wasted", "it counts", "glad I tried",
                          "it led somewhere", "worth it in its own way"]),
        WordTheme(name: "comparison",
                  triggers: ["compar", "everyone", "others", "jealous", "envy", "envious", "instagram", "linkedin"],
                  heavy: ["smaller than them", "left behind", "envious", "not measuring up", "invisible next to them",
                          "like I'm in the wrong race"],
                  light: ["on my own path", "happy for them", "inspired by them", "enough as I am",
                          "running my own race", "not in competition"]),
        WordTheme(name: "decisions",
                  triggers: ["decid", "decision", "choice", "choose", "option", "should", "unsure", "indecis", "torn"],
                  heavy: ["torn", "paralyzed by options", "scared to choose wrong", "going in circles",
                          "afraid of regret", "stuck between two"],
                  light: ["clearer", "allowed to change my mind", "settled on it", "trusting my gut",
                          "no wrong door", "decided for now"]),
        WordTheme(name: "being alone",
                  triggers: ["alone", "lonely", "lonel", "isolat", "single", "nobody", "no one"],
                  heavy: ["unseen", "left out", "like nobody gets it", "aching for company", "unwanted",
                          "on the outside", "homesick"],
                  light: ["at peace on my own", "good company to myself", "reached out", "connected",
                          "free", "independent", "content alone"]),
        WordTheme(name: "love",
                  triggers: ["love", "crush", "date", "dating", "relationship", "partner", "boyfriend", "girlfriend",
                             "ex", "breakup", "romance", "romant"],
                  heavy: ["unlovable", "heartsick", "rejected", "longing", "replaced", "not chosen",
                          "afraid to hope", "missing them"],
                  light: ["worthy of love", "hopeful about love", "cared for", "whole on my own",
                          "warm", "chosen", "open-hearted", "fond"]),
        WordTheme(name: "friends",
                  triggers: ["friend", "social", "party", "group", "people", "text", "ignored"],
                  heavy: ["left out", "forgotten", "like a burden", "awkward", "misunderstood",
                          "too much for them", "on the edge of the group"],
                  light: ["included", "understood", "laughed with", "appreciated", "close",
                          "glad I reached out", "at ease with them"]),
        WordTheme(name: "family",
                  triggers: ["family", "mom", "dad", "mother", "father", "parent", "brother", "sister", "home"],
                  heavy: ["like a disappointment", "guilty", "unheard", "pressured by them",
                          "homesick", "caught in the middle", "resentful"],
                  light: ["supported", "understood at home", "grateful for them", "close to them",
                          "my own person", "at home", "proud of them"]),
        WordTheme(name: "rejection",
                  triggers: ["reject", "turned down", "no", "denied", "ghost", "dumped"],
                  heavy: ["not wanted", "humiliated", "like I'm the problem", "stung", "discarded",
                          "doubting myself"],
                  light: ["it's their loss", "one door of many", "still worth something", "redirected",
                          "proud I asked", "steadier than I thought"]),
        WordTheme(name: "worry",
                  triggers: ["worr", "anxi", "nervous", "scare", "fear", "afraid", "panic", "what if", "stress"],
                  heavy: ["on edge", "bracing for the worst", "jittery", "tight-chested", "spiraling",
                          "can't switch off", "catastrophizing", "restless"],
                  light: ["safe right now", "grounded", "it might be okay", "breathing easier",
                          "present", "loosening", "steady", "reassured"]),
        WordTheme(name: "sadness",
                  triggers: ["sad", "cry", "down", "depress", "blue", "hurt", "grief", "griev", "miss"],
                  heavy: ["heavy-hearted", "tearful", "hollow", "aching", "weighed down", "grieving",
                          "flat", "low"],
                  light: ["soft", "comforted", "tender", "lighter after crying", "held", "hopeful again",
                          "gentle with myself", "okay to feel it"]),
        WordTheme(name: "anger",
                  triggers: ["angry", "anger", "mad", "furious", "annoy", "irritat", "frustrat", "rage", "unfair"],
                  heavy: ["wronged", "boiling", "resentful", "fed up", "disrespected", "tense in my jaw",
                          "bitter"],
                  light: ["cooled down", "clear about my limits", "let it go", "heard", "standing up for myself",
                          "calmer", "fair to myself"]),
        WordTheme(name: "tiredness",
                  triggers: ["tired", "exhaust", "sleep", "drain", "burn", "fatigue", "worn", "weary"],
                  heavy: ["running on empty", "foggy", "heavy-limbed", "burnt out", "sleep-deprived",
                          "too tired to care", "depleted"],
                  light: ["rested", "recharged", "allowed to rest", "slow and fine", "cozy", "restored",
                          "refreshed"]),
        WordTheme(name: "self-worth",
                  triggers: ["worthless", "hate myself", "useless", "ugly", "stupid", "enough", "myself", "self", "weak"],
                  heavy: ["not enough", "unworthy", "ashamed of myself", "small", "harsh on myself",
                          "like I have to earn it", "defective"],
                  light: ["enough as I am", "worthy without earning it", "kind to myself", "accepting",
                          "on my own side", "unconditionally okay", "proud of who I am"]),
        WordTheme(name: "body",
                  triggers: ["body", "weight", "fat", "skinny", "face", "look", "sick", "ill", "pain", "health"],
                  heavy: ["uncomfortable in my skin", "self-conscious", "unwell", "achy", "on display",
                          "critical of my body"],
                  light: ["at home in my body", "strong", "cared for", "healing", "comfortable",
                          "grateful for my body"]),
        WordTheme(name: "money",
                  triggers: ["money", "broke", "rent", "debt", "pay", "bill", "loan", "afford", "cost"],
                  heavy: ["financially stuck", "insecure", "worried about bills", "behind on money",
                          "trapped", "guilty spending"],
                  light: ["secure", "on top of it", "careful and okay", "enough for now", "resourceful",
                          "relieved"]),
        WordTheme(name: "pressure",
                  triggers: ["pressure", "deadline", "busy", "overwhelm", "too much", "rush", "expect", "perfect"],
                  heavy: ["buried", "stretched thin", "pulled in every direction", "drowning in tasks",
                          "behind on everything", "under a microscope"],
                  light: ["one thing at a time", "on top of it", "allowed to be imperfect", "focused",
                          "relieved it's done", "making room to breathe"]),
        WordTheme(name: "good things",
                  triggers: ["happy", "good", "great", "win", "proud", "excit", "fun", "joy", "grateful", "thank", "laugh"],
                  heavy: ["afraid it won't last", "guilty for being happy", "waiting for the catch",
                          "unsure I deserve it"],
                  light: ["proud", "lit up", "giddy", "glowing", "satisfied", "light", "grateful",
                          "like myself"]),
    ]

    /// The theme your word belongs to, if any. First by the word itself (or any word
    /// in a short phrase) starting with a trigger; then, for a single word that matches
    /// none, by the on-device embedding if it sits close enough to a theme's triggers.
    static func theme(for word: String, embedding: NLEmbedding?) -> WordTheme? {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        let parts = key.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        func matches(_ trigger: String) -> Bool {
            if trigger.contains(" ") { return key.contains(trigger) }
            // Very short triggers ("ex", "no", "ill") only count as a whole word.
            if trigger.count <= 3 { return parts.contains(trigger) }
            return parts.contains { $0.hasPrefix(trigger) }
        }
        if let direct = all.first(where: { $0.triggers.contains(where: matches) }) { return direct }

        guard let embedding, parts.count == 1, embedding.contains(key) else { return nil }
        var best: (theme: WordTheme, distance: Double)?
        for theme in all {
            for trigger in theme.triggers where !trigger.contains(" ") && embedding.contains(trigger) {
                let d = embedding.distance(between: key, and: trigger)
                if d < (best?.distance ?? .infinity) { best = (theme, d) }
            }
        }
        // Only when it's genuinely close; otherwise the general feeling words are better.
        guard let best, best.distance < 0.8 else { return nil }
        return best.theme
    }
}
