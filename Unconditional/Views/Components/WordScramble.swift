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
    static let heavy = [
        "tired", "anxious", "stuck", "lonely", "ashamed", "overwhelmed", "behind", "drained",
        "restless", "sad", "frustrated", "worried", "numb", "small", "scattered", "tense",
        "disappointed", "afraid", "guilty", "lost", "pressured", "hurt", "bored", "jealous",
        "unsure", "exhausted", "irritable", "embarrassed", "discouraged", "empty",
    ]
    static let light = [
        "calm", "hopeful", "proud", "grateful", "curious", "relieved", "rested", "connected",
        "steady", "content", "excited", "playful", "safe", "capable", "peaceful", "warm",
        "focused", "energized", "gentle", "free", "loved", "amused", "clear", "brave",
        "patient", "open", "satisfied", "inspired", "cared for", "glad",
    ]

    /// Below this, a slide is "in between" rather than heavier or lighter.
    static let middle = 0.15

    /// Apple's on-device word embedding: words used in similar ways sit close together.
    /// Nil on the rare device without it; then words come in list order.
    private static let embedding = NLEmbedding.wordEmbedding(for: .english)

    /// Words to offer next: from the side you slid toward (both sides when it was
    /// in between), closest in meaning to your word first. `shuffle` steps through
    /// the rest of the list, so "show others" never repeats until it runs out.
    static func related(to word: String, leaning lean: Double, excluding used: Set<String> = [],
                        count: Int = 6, shuffle: Int = 0) -> [String] {
        let key = word.lowercased()
        let pool: [String]
        if lean <= -middle { pool = heavy } else if lean >= middle { pool = light } else { pool = interleaved }
        let candidates = pool.filter { $0 != key && !used.contains($0) }
        guard !candidates.isEmpty else { return [] }

        let ranked: [String]
        if let embedding, embedding.contains(key) {
            ranked = candidates.enumerated()
                .map { (word: $0.element, order: $0.offset, distance: embedding.distance(between: key, and: $0.element)) }
                .sorted { ($0.distance, $0.order) < ($1.distance, $1.order) }
                .map(\.word)
        } else {
            ranked = candidates
        }
        let start = (shuffle * count) % ranked.count
        return (0..<min(count, ranked.count)).map { ranked[(start + $0) % ranked.count] }
    }

    private static var interleaved: [String] {
        zip(heavy, light).flatMap { [$0, $1] }
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

    /// Where the kept words sit on average, -1 to 1. Zero when there are none.
    static func averageLean(_ words: [KeptWord]) -> Double {
        guard !words.isEmpty else { return 0 }
        return words.map(\.lean).reduce(0, +) / Double(words.count)
    }

    /// The first word of what was typed, tidied. Nil when nothing was typed.
    static func firstWord(of typed: String) -> String? {
        let word = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace).first.map(String.init)?
            .trimmingCharacters(in: .punctuationCharacters).lowercased()
        return (word?.isEmpty ?? true) ? nil : word
    }

    /// Slate blue for heavier, warm gold for lighter, the orb's own soft green in between.
    static func color(for lean: Double, palette: OrbPalette) -> Color {
        let middleColor = palette.colors[0]
        if lean < 0 { return middleColor.mix(with: Color(hex: 0x7F8FB0), by: min(1, -lean)) }
        return middleColor.mix(with: Color(hex: 0xF2B872), by: min(1, lean))
    }
}

/// "Words": type one word, then slide its little orb toward heavier or lighter.
/// How far you slide is how much. Related feeling words then bubble out of it;
/// tap one to slide it too, or type your own. What you keep becomes the entry.
struct WordScramble: View {
    @Binding var text: String
    /// The average lean of the kept words, -1 to 1, so the "how does this sit?" slider can start there.
    var onLean: (Double) -> Void = { _ in }

    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kept: [KeptWord] = []
    /// The word in the middle, waiting to be slid.
    @State private var current: String?
    @State private var draft = ""
    @State private var drag: CGFloat = 0
    @State private var bubbles: [String] = []
    @State private var bubblesOut = false
    @State private var shuffle = 0
    /// The last word you slid, and which way, so "show others" stays on the same side.
    @State private var lastWord = ""
    @State private var lastLean = 0.0
    @State private var keptCount = 0
    @FocusState private var typing: Bool

    private let arenaHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 16) {
            PaperHeading(title: "One word at a time",
                         subtitle: "Type a word for how you feel, then slide it. Left is heavier, right is lighter. How far is how much.")

            arena

            if current == nil {
                HStack {
                    TextField(kept.isEmpty ? "One word…" : "Another word…", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($typing)
                        .onSubmit(useDraft)
                    if FeelingWords.firstWord(of: draft) != nil {
                        Button("Use", action: useDraft)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .paperCard(padding: 14)
            }

            if !kept.isEmpty { keptCluster }
        }
        .onChange(of: kept) { _, words in
            text = FeelingWords.compose(words)
            if !words.isEmpty { onLean(FeelingWords.averageLean(words)) }
        }
        .onAppear { if kept.isEmpty { text = "" } }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: keptCount)
    }

    // MARK: The space you slide words across

    private var arena: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let reach = max(80, width * 0.38)
            let lean = Double(max(-1, min(1, drag / reach)))
            ZStack {
                // A faint wash from heavy to light, so the direction is felt before it's read.
                RoundedRectangle(cornerRadius: Paper.cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [FeelingWords.color(for: -1, palette: palette).opacity(0.18),
                                                  Paper.card,
                                                  FeelingWords.color(for: 1, palette: palette).opacity(0.22)],
                                         startPoint: .leading, endPoint: .trailing))
                HStack {
                    Label("heavier", systemImage: "chevron.left")
                    Spacer()
                    Label { Text("lighter") } icon: { Image(systemName: "chevron.right") }
                        .labelStyle(TrailingIconLabel())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)

                if let current {
                    WordOrb(word: current, color: FeelingWords.color(for: lean, palette: palette), size: orbSize(current))
                        .scaleEffect(1 + 0.12 * abs(lean))
                        .offset(x: drag)
                        .gesture(slide(reach: reach))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .accessibilityElement()
                        .accessibilityLabel(current)
                        .accessibilityHint("Slide left for heavier, right for lighter")
                        .accessibilityAction(named: "A little heavier") { keep(current, lean: -0.3) }
                        .accessibilityAction(named: "A lot heavier") { keep(current, lean: -0.9) }
                        .accessibilityAction(named: "A little lighter") { keep(current, lean: 0.3) }
                        .accessibilityAction(named: "A lot lighter") { keep(current, lean: 0.9) }
                    Text(FeelingWords.describe(lean))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .opacity(abs(drag) > 4 ? 1 : 0)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 14)
                } else if !bubbles.isEmpty {
                    ForEach(Array(bubbles.enumerated()), id: \.element) { index, word in
                        let angle = CGFloat(index) / CGFloat(bubbles.count) * 2 * .pi - .pi / 2
                        let radius = min(width * 0.33, arenaHeight * 0.34)
                        Button {
                            pick(word)
                        } label: {
                            WordOrb(word: word, color: FeelingWords.color(for: lastLean * 0.6, palette: palette), size: 74, small: true)
                        }
                        .buttonStyle(.plain)
                        .offset(x: bubblesOut ? cos(angle) * radius : 0,
                                y: bubblesOut ? sin(angle) * radius + 10 : 10)
                        .opacity(bubblesOut ? 1 : 0)
                        .scaleEffect(bubblesOut ? 1 : 0.3)
                    }
                    Button("show others", systemImage: "shuffle", action: showOthers)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(.background.opacity(0.6), in: Capsule())
                        .offset(y: 10)
                } else {
                    // Waiting for a first word: a resting orb holds the space.
                    OrbView(palette: palette, speed: 0.35)
                        .frame(width: 70, height: 70)
                        .opacity(0.7)
                        .onTapGesture { typing = true }
                }
            }
            .frame(width: width, height: arenaHeight)
        }
        .frame(height: arenaHeight)
        .animation(reduceMotion ? nil : .calm, value: current)
    }

    private func slide(reach: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in drag = value.translation.width }
            .onEnded { value in
                let lean = Double(max(-1, min(1, value.translation.width / reach)))
                if abs(lean) >= 0.1, let current {
                    keep(current, lean: lean)
                } else {
                    withAnimation(.spring(duration: 0.5, bounce: 0.35)) { drag = 0 }
                }
            }
    }

    private func orbSize(_ word: String) -> CGFloat {
        min(150, max(100, CGFloat(word.count) * 12 + 44))
    }

    // MARK: What you've kept

    private var keptCluster: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you've kept")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ChipFlow {
                ForEach(kept) { item in
                    Button {
                        withAnimation(.calm) { kept.removeAll { $0.id == item.id } }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(FeelingWords.color(for: item.lean, palette: palette))
                                .frame(width: 10, height: 10)
                            Text(item.word)
                            Image(systemName: "xmark")
                                .imageScale(.small)
                                .foregroundStyle(.tertiary)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(FeelingWords.color(for: item.lean, palette: palette).opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(item.word), \(FeelingWords.describe(item.lean))")
                    .accessibilityHint("Removes it")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func useDraft() {
        guard let word = FeelingWords.firstWord(of: draft) else { return }
        draft = ""
        typing = false
        pick(word)
    }

    private func pick(_ word: String) {
        drag = 0
        bubblesOut = false
        withAnimation(.calm) {
            bubbles = []
            current = word
        }
    }

    private func keep(_ word: String, lean: Double) {
        withAnimation(.calm) {
            kept.removeAll { $0.word == word }
            kept.append(KeptWord(word: word, lean: lean))
            current = nil
            drag = 0
        }
        keptCount += 1
        lastWord = word
        lastLean = lean
        shuffle = 0
        offerBubbles()
    }

    private func showOthers() {
        shuffle += 1
        bubblesOut = false
        offerBubbles()
    }

    /// Related words bubble out of the middle, as if the orb let them go.
    private func offerBubbles() {
        let used = Set(kept.map(\.word))
        bubbles = FeelingWords.related(to: lastWord, leaning: lastLean, excluding: used, shuffle: shuffle)
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.3)) { bubblesOut = true }
        }
    }
}

/// A word sitting inside a small soft orb.
private struct WordOrb: View {
    let word: String
    let color: Color
    let size: CGFloat
    var small = false

    var body: some View {
        ZStack {
            MiniOrb(color: color, seed: Double(word.count))
            Text(word)
                .font(small ? .caption.weight(.semibold) : .system(.headline, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.12)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

/// Text first, then the icon, for "lighter ›".
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
