import SwiftUI
import NaturalLanguage

/// One feeling word you kept, and how far you slid it.
/// `lean` runs from -1 (much heavier) to 1 (much lighter).
struct KeptWord: Identifiable, Equatable {
    let id = UUID()
    var word: String
    var lean: Double
}

/// The feeling words that bubble up after you slide a word, and how a set of
/// kept words is written into the entry.
enum FeelingWords {
    // Each side comes in two strengths, so a small slide and a big one offer
    // different words: "a bit off" isn't the same as "overwhelmed".
    static let heavyMild = [
        "tired", "unsure", "restless", "bored", "stuck", "worried", "tense", "scattered",
        "disappointed", "behind", "drained", "irritable", "uneasy", "flat", "distracted",
        "low", "frustrated", "impatient", "lonely", "sad", "awkward", "pressured",
        "wistful", "homesick", "sluggish", "foggy", "groggy", "antsy", "jittery", "edgy",
        "cranky", "grumpy", "moody", "blue", "glum", "deflated", "underwhelmed", "unmotivated",
        "listless", "weary", "achy", "overstimulated", "stretched thin", "rushed", "nervous",
        "self-conscious", "insecure", "doubtful", "hesitant", "conflicted", "torn", "unsettled",
        "on edge", "left out", "misunderstood", "unseen", "envious", "annoyed", "touchy",
        "fragile", "bittersweet", "melancholy", "preoccupied", "overthinking", "second-guessing",
        "out of place", "nostalgic", "indecisive",
    ]
    static let heavyStrong = [
        "overwhelmed", "hopeless", "ashamed", "exhausted", "panicked", "devastated", "worthless",
        "empty", "numb", "crushed", "furious", "terrified", "trapped", "heartbroken", "desperate",
        "guilty", "afraid", "hurt", "defeated", "jealous", "lost", "embarrassed",
        "dread", "despair", "grief", "anguished", "betrayed", "humiliated", "rejected",
        "abandoned", "isolated", "paralyzed", "frozen", "burnt out", "shattered", "helpless",
        "powerless", "invisible", "unwanted", "unlovable", "disgusted", "mortified", "spiraling",
        "frantic", "suffocated", "cornered", "bitter", "resentful", "hollow", "depleted",
        "wrecked", "raw", "inadequate", "like a failure", "like a burden", "regretful",
        "haunted", "tormented", "livid", "seething", "grieving", "aching", "sick with worry",
        "like a fraud", "broken", "alone in it",
    ]
    static let lightMild = [
        "calm", "okay", "steady", "content", "rested", "relieved", "gentle", "patient",
        "curious", "open", "focused", "settled", "warm", "safe", "clear", "glad", "hopeful",
        "amused", "comfortable", "satisfied", "cozy", "lighter",
        "mellow", "easygoing", "unhurried", "grounded", "balanced", "centered", "refreshed",
        "awake", "alert", "interested", "absorbed", "reflective", "thoughtful", "tender",
        "soft", "accepted", "understood", "included", "reassured", "at ease", "snug",
        "pleasant", "cheerful", "upbeat", "sunny", "competent", "productive", "organized",
        "prepared", "ready", "motivated", "encouraged", "appreciative", "fond", "friendly",
        "sociable", "silly", "goofy", "nourished", "forgiving", "unbothered", "light-hearted",
        "breezy", "tickled", "useful",
    ]
    static let lightStrong = [
        "joyful", "proud", "grateful", "excited", "inspired", "loved", "energized", "free",
        "brave", "elated", "delighted", "playful", "connected", "alive", "peaceful", "confident",
        "capable", "thrilled", "cared for", "radiant", "uplifted", "moved",
        "ecstatic", "euphoric", "blissful", "giddy", "exhilarated", "triumphant", "accomplished",
        "fulfilled", "empowered", "unstoppable", "fearless", "liberated", "awestruck", "amazed",
        "enchanted", "full of wonder", "adored", "cherished", "seen", "belonging", "at home",
        "whole", "serene", "tranquil", "renewed", "revived", "glowing", "bubbly", "overjoyed",
        "jubilant", "passionate", "determined", "purposeful", "resilient", "strong", "worthy",
        "enough", "treasured", "deeply at peace", "in love with life", "on top of the world",
        "like myself again", "unafraid", "hopeful again",
    ]
    static var heavy: [String] { heavyMild + heavyStrong }
    static var light: [String] { lightMild + lightStrong }

    /// From here on, a slide counts as strong rather than mild.
    static let strong = 0.5

    /// Below this, a slide is "in between" rather than heavier or lighter.
    static let middle = 0.15

    /// Apple's on-device word embedding: words used in similar ways sit close together.
    /// Nil on the rare device without it; then words come in list order.
    private static let embedding = NLEmbedding.wordEmbedding(for: .english)

    /// Words to offer next. If your word belongs to a theme (failure, work, the future,
    /// someone you miss...), most come from that theme, on the side you slid toward: so
    /// "failure" slid heavier offers "not good enough" or "like a fraud", and slid lighter
    /// "still learning" or "allowed to try again". The rest come from the general list
    /// for that side and strength, closest in meaning first, with one wildcard further out.
    /// `shuffle` steps through for "other words"; `seed` varies the wildcard between slides.
    static func related(to word: String, leaning lean: Double, excluding used: Set<String> = [],
                        count: Int = 6, shuffle: Int = 0, seed: Int = 0) -> [String] {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let skip = used.union([key])

        // 1. Words from your word's theme, on your side.
        var themed: [String] = []
        if let theme = WordThemes.theme(for: key, embedding: embedding) {
            switch lean {
            case ...(-middle): themed = theme.heavy
            case middle...: themed = theme.light
            default: themed = zip(theme.heavy, theme.light).flatMap { [$0, $1] }
            }
            // A big slide starts from the other half of the theme, so "a little"
            // and "a lot" still offer different words.
            if abs(lean) >= strong, !themed.isEmpty {
                let half = themed.count / 2
                themed = Array(themed[half...] + themed[..<half])
            }
            themed = themed.filter { !skip.contains($0) }
        }

        // 2. The general list for that side and strength, closest in meaning first.
        let pool: [String]
        switch lean {
        case ...(-strong): pool = heavyStrong
        case ...(-middle): pool = heavyMild
        case strong...: pool = lightStrong
        case middle...: pool = lightMild
        default: pool = interleaved
        }
        let candidates = pool.filter { !skip.contains($0) && !themed.contains($0) }
        let ranked: [String]
        if let embedding, embedding.contains(key) {
            ranked = candidates.enumerated()
                .map { (word: $0.element, order: $0.offset, distance: embedding.distance(between: key, and: $0.element)) }
                .sorted { ($0.distance, $0.order) < ($1.distance, $1.order) }
                .map(\.word)
        } else {
            ranked = candidates
        }
        guard !themed.isEmpty || !ranked.isEmpty else { return [] }

        // Mostly specific: a few from the theme, then the nearest general
        // words, and one wildcard from further down the list for a little range.
        func rotate(_ list: [String], by n: Int) -> [String] {
            guard !list.isEmpty else { return list }
            let i = ((n % list.count) + list.count) % list.count
            return Array(list[i...] + list[..<i])
        }
        let themeCount = min(themed.count, max(count - 2, 1), max(themed.count / 2, 1))
        var picks = Array(rotate(themed, by: shuffle * themeCount).prefix(themeCount))
        let nearCount = max(count - picks.count - 1, 0)
        let general = rotate(ranked, by: shuffle * max(nearCount, 1))
        picks += general.prefix(nearCount)
        let further = Array(general.dropFirst(nearCount))
        if picks.count < count, !further.isEmpty {
            let wild = Array(further.dropFirst(min(further.count - 1, further.count / 3)))
            picks.append(wild[abs(seed) % wild.count])
        }
        // If the theme and the nearest words ran short, fill from what's left.
        for extra in further where picks.count < count && !picks.contains(extra) { picks.append(extra) }
        return picks
    }

    private static var interleaved: [String] {
        zip(heavyMild, lightMild).flatMap { [$0, $1] }
    }

    /// "heavier, a lot", "lighter, a little", or "in between". Plain words, no numbers.
    static func describe(_ lean: Double) -> String {
        let size = abs(lean)
        guard size >= middle else { return "in between" }
        let side = lean < 0 ? "heavier" : "lighter"
        let amount = size < 0.45 ? "a little" : size < 0.8 ? "quite" : "a lot"
        return "\(side), \(amount)"
    }

    /// What goes into the journal: "tired (heavier, a lot) · hopeful (lighter, a little)".
    static func compose(_ words: [KeptWord]) -> String {
        words.map { "\($0.word) (\(describe($0.lean)))" }.joined(separator: " · ")
    }

    /// Reads `compose` back, so going back to Words finds what you kept.
    /// Leans come back as the middle of their description ("quite" is 0.6).
    static func parse(_ text: String) -> [KeptWord] {
        text.components(separatedBy: " · ").compactMap { piece in
            guard piece.hasSuffix(")"), let open = piece.range(of: " (", options: .backwards) else { return nil }
            let word = String(piece[..<open.lowerBound])
            let description = piece[open.upperBound...].dropLast()
            guard !word.isEmpty else { return nil }
            let sign: Double = description.hasPrefix("heavier") ? -1 : description.hasPrefix("lighter") ? 1 : 0
            let size = description.hasSuffix("a lot") ? 0.9 : description.hasSuffix("quite") ? 0.6 : 0.3
            return KeptWord(word: word, lean: sign * size)
        }
    }

    /// Where the kept words sit on average, -1 to 1. Zero when there are none.
    static func averageLean(_ words: [KeptWord]) -> Double {
        guard !words.isEmpty else { return 0 }
        return words.map(\.lean).reduce(0, +) / Double(words.count)
    }

    /// An orb that fits its word: big enough for the letters with a soft margin,
    /// never tiny and never huge.
    static func orbSize(for word: String, small: Bool) -> CGFloat {
        let letters = CGFloat(word.count)
        return small ? min(max(letters * 7.2 + 34, 60), 108) : min(max(letters * 11.5 + 48, 100), 180)
    }

    /// A small, steady difference for each bubble: hue, brightness, glow, and size.
    /// Based on the word, so the same word always looks the same.
    static func bubbleShade(index: Int, word: String) -> (hue: Double, brightness: Double, glow: CGFloat, size: CGFloat) {
        let seed = word.unicodeScalars.reduce(index * 31) { ($0 &* 33 &+ Int($1.value)) & 0xFFFF }
        let a = Double(seed % 100) / 100
        let b = Double((seed / 100) % 100) / 100
        return (hue: -28 + 56 * a, brightness: -0.04 + 0.1 * b, glow: CGFloat(4 + 10 * b), size: CGFloat(12 * a))
    }

    /// The first word of what was typed, tidied. Nil when nothing was typed.
    static func firstWord(of typed: String) -> String? {
        let word = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace).first.map(String.init)?
            .trimmingCharacters(in: .punctuationCharacters).lowercased()
        return (word?.isEmpty ?? true) ? nil : word
    }

    /// Words sit on the orb in white, except on Pearl, which is too pale for it.
    static func ink(on palette: OrbPalette) -> Color {
        palette == .pearl ? Color(hex: 0x3F3A52) : .white
    }

    /// Slate blue for heavier, warm gold for lighter, the orb's own soft green in between.
    static func color(for lean: Double, palette: OrbPalette) -> Color {
        let middleColor = palette.colors[0]
        if lean < 0 { return middleColor.mix(with: Color(hex: 0x7F8FB0), by: min(1, -lean)) }
        return middleColor.mix(with: Color(hex: 0xF2B872), by: min(1, lean))
    }
}

/// "Words", one quiet screen at a time:
/// 1. just an orb with a place for one word
/// 2. the word in its orb: slide it left for heavier, right for lighter (how far is how much)
/// 3. related feeling words bubble out around what you've kept; tap one to slide it too
/// What you keep becomes the entry.
struct WordScramble: View {
    @Binding var text: String
    /// The average lean of the kept words, -1 to 1.
    var onLean: (Double) -> Void = { _ in }

    private enum Phase: Equatable { case typing, sliding(String), more }

    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .midnight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .typing
    @State private var kept: [KeptWord] = []
    @State private var draft = ""
    @State private var drag: CGFloat = 0
    @State private var bubbles: [String] = []
    @State private var shuffle = 0
    /// Changes with each word you slide, so the same word doesn't always bring the same suggestions.
    @State private var seed = 0
    /// The last word you slid, and which way, so "other words" stays on the same side.
    @State private var lastWord = ""
    @State private var lastLean = 0.0
    @State private var keptCount = 0
    @FocusState private var typing: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch phase {
                case .typing: typingView
                case .sliding(let word): slidingView(word, width: proxy.size.width)
                case .more: moreView(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .animation(reduceMotion ? nil : .calm, value: phase)
        .onChange(of: kept) { _, words in
            text = FeelingWords.compose(words)
            if !words.isEmpty { onLean(FeelingWords.averageLean(words)) }
        }
        .onAppear {
            // Coming back from the next step: pick up where you were.
            guard kept.isEmpty else { return }
            let earlier = FeelingWords.parse(text)
            guard let last = earlier.last else { return }
            kept = earlier
            lastWord = last.word
            lastLean = last.lean
            phase = .more
            offerBubbles()
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: keptCount)
    }

    // MARK: 1. One word

    /// An orb with a place to type inside it. Nothing else.
    private var typingView: some View {
        ZStack {
            OrbView(palette: palette, speed: 0.4)
                .frame(width: 230, height: 230)
                .opacity(0.85)
            TextField("", text: $draft, prompt: Text(kept.isEmpty ? "one word" : "another word").foregroundStyle(FeelingWords.ink(on: palette).opacity(0.7)))
                .font(.system(.title, design: .serif))
                .foregroundStyle(FeelingWords.ink(on: palette))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($typing)
                .onSubmit(useDraft)
                .frame(width: 180)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .offset(y: -40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Tapping anywhere once there's a word moves it on, and so does putting the
        // keyboard away, so Return isn't the only way forward.
        .contentShape(Rectangle())
        .onTapGesture {
            if FeelingWords.firstWord(of: draft) != nil { useDraft() } else { typing = true }
        }
        .overlay(alignment: .bottom) {
            if FeelingWords.firstWord(of: draft) != nil {
                Button("Slide it", systemImage: "arrow.left.and.right", action: useDraft)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(.tint.opacity(0.13), in: Capsule())
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .animation(.calm, value: draft.isEmpty)
        .onChange(of: typing) { _, focused in
            if !focused && FeelingWords.firstWord(of: draft) != nil { useDraft() }
        }
        .transition(.opacity)
        .task {
            // Focus after the step's own transition, or the keyboard may not come up.
            try? await Task.sleep(for: .milliseconds(350))
            typing = true
        }
    }

    // MARK: 2. Slide it

    private func slidingView(_ word: String, width: CGFloat) -> some View {
        let reach = max(80, width * 0.38)
        let lean = Double(max(-1, min(1, drag / reach)))
        return ZStack {
            HStack {
                Text("heavier")
                Spacer()
                Text("lighter")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            WordOrb(word: word, color: FeelingWords.color(for: lean, palette: palette), size: orbSize(word), ink: FeelingWords.ink(on: palette))
                .scaleEffect(1 + 0.12 * abs(lean))
                .offset(x: drag)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel(word)
                .accessibilityHint("Slide left for heavier, right for lighter")
                .accessibilityAction(named: "A little heavier") { keep(word, lean: -0.3) }
                .accessibilityAction(named: "A lot heavier") { keep(word, lean: -0.9) }
                .accessibilityAction(named: "A little lighter") { keep(word, lean: 0.3) }
                .accessibilityAction(named: "A lot lighter") { keep(word, lean: 0.9) }
        }
        .offset(y: -40)
        // The whole screen is the slide, so you don't have to land on the orb itself.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(slide(word, reach: reach))
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    /// Wherever you let go is how it sits. Barely moving it, or just tapping,
    /// keeps it "in between", which is a real answer too.
    private func slide(_ word: String, reach: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in drag = value.translation.width }
            .onEnded { value in
                let lean = Double(max(-1, min(1, value.translation.width / reach)))
                keep(word, lean: abs(lean) < FeelingWords.middle ? 0 : lean)
            }
    }

    private func orbSize(_ word: String) -> CGFloat {
        FeelingWords.orbSize(for: word, small: false)
    }

    // MARK: 3. More words bubble out

    /// What you've kept sits quietly in the middle; new words float around it.
    private func moreView(size: CGSize) -> some View {
        let radius = min(size.width * 0.36, size.height * 0.3)
        return ZStack {
            VStack(spacing: 4) {
                ForEach(kept) { item in
                    // Dark text for reading, with the orb's light around it: it's yours now.
                    // Tap it (the small x shows how) to take it back out.
                    Button { remove(item) } label: {
                        HStack(spacing: 5) {
                            Text(item.word)
                                .font(.system(.callout, design: .serif).weight(.medium))
                                .foregroundStyle(.primary)
                                .ownGlow(FeelingWords.color(for: item.lean, palette: palette), radius: 6)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityLabel("\(item.word), \(FeelingWords.describe(item.lean))")
                    .accessibilityHint("Removes this word")
                }
            }
            .frame(maxWidth: radius * 1.2)

            ForEach(Array(bubbles.enumerated()), id: \.element) { index, word in
                let angle = CGFloat(index) / CGFloat(bubbles.count) * 2 * .pi - .pi / 2
                Button { pick(word) } label: {
                    // Each bubble its own shade and glow, like no two feelings are quite alike.
                    let tint = FeelingWords.bubbleShade(index: index, word: word)
                    WordOrb(word: word, color: FeelingWords.color(for: lastLean * 0.6, palette: palette), size: FeelingWords.orbSize(for: word, small: true) + tint.size * 0.4,
                            ink: FeelingWords.ink(on: palette), small: true)
                        .hueRotation(.degrees(tint.hue))
                        .brightness(tint.brightness)
                        .shadow(color: FeelingWords.color(for: lastLean, palette: palette).opacity(0.5), radius: tint.glow)
                }
                .buttonStyle(.plain)
                .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                // Each one floats out of the middle as it appears.
                .transition(.asymmetric(
                    insertion: .offset(x: -cos(angle) * radius, y: -sin(angle) * radius)
                        .combined(with: .scale(scale: 0.3)).combined(with: .opacity),
                    removal: .opacity))
            }

            HStack(spacing: 24) {
                Button("other words", systemImage: "shuffle", action: showOthers)
                Button("type one", systemImage: "character.cursor.ibeam") { phase = .typing }
                Button("start over", systemImage: "arrow.counterclockwise") {
                    withAnimation(.calm) { kept.removeAll() }
                    phase = .typing
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 8)
        }
        .offset(y: -20)
        .transition(.opacity)
    }

    // MARK: Actions

    private func useDraft() {
        guard let word = FeelingWords.firstWord(of: draft) else { return }
        draft = ""
        pick(word)
    }

    private func pick(_ word: String) {
        drag = 0
        bubbles = []
        typing = false
        phase = .sliding(word)
    }

    private func keep(_ word: String, lean: Double) {
        kept.removeAll { $0.word == word }
        kept.append(KeptWord(word: word, lean: lean))
        drag = 0
        keptCount += 1
        lastWord = word
        lastLean = lean
        shuffle = 0
        seed = Int.random(in: 0..<1000)
        phase = .more
        offerBubbles()
    }

    private func remove(_ item: KeptWord) {
        withAnimation(.calm) { kept.removeAll { $0.id == item.id } }
        if kept.isEmpty { phase = .typing }
    }

    private func showOthers() {
        shuffle += 1
        offerBubbles()
    }

    /// Related words bubble out of the middle, as if the orb let them go.
    private func offerBubbles() {
        let used = Set(kept.map(\.word))
        var next = FeelingWords.related(to: lastWord, leaning: lastLean, excluding: used, count: 5, shuffle: shuffle, seed: seed)
        // If one side has run out, offer from both.
        if next.isEmpty {
            next = FeelingWords.related(to: lastWord, leaning: 0, excluding: used, count: 5, shuffle: shuffle, seed: seed)
        }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.3)) { bubbles = next }
    }
}

/// A word sitting inside a small soft orb.
private struct WordOrb: View {
    let word: String
    let color: Color
    let size: CGFloat
    var ink: Color = .white
    var small = false

    var body: some View {
        ZStack {
            MiniOrb(color: color, seed: Double(word.count))
            Text(word)
                .font(small ? .caption.weight(.semibold) : .system(.headline, design: .serif))
                .foregroundStyle(ink)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                // Longer phrases like "on top of the world" wrap onto two lines.
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, size * 0.12)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}
