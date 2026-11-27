import SwiftUI
import SwiftData

/// "I'm spiraling": three calm moments, one at a time, with as little to read as possible.
/// 1. Breathe: the orb breathes three slow breaths, and you breathe with it.
/// 2. Pick: a few heavy words drift by (your loops among them). Tap what's in your head.
/// 3. Release: drag each word down into the water to let it go, or up into the
///    cloud to save it for Sunday, when the cloud rains it back for a calm look.
struct ThoughtResetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @Query private var laughs: [Laugh]

    private enum Step: Equatable { case breathe, pick, release, closing }
    enum Destination { case water, cloud }

    @State private var step: Step = .breathe
    @State private var pool: [String] = []
    @State private var picked: [String] = []
    @State private var own = ""
    @State private var placed: [String: Destination] = [:]
    @State private var dragging: String?
    @State private var dragOffset: CGSize = .zero
    @State private var ripple = 0
    @State private var rippleX: CGFloat = 0.5
    @State private var closingRipple = 0
    @State private var breathStart = Date.now
    @State private var cloudPuff = 0
    @State private var fuseTarget: String?
    @State private var fuseCount = 0
    @State private var bursts: [Burst] = []

    struct Burst: Identifiable {
        let id = UUID()
        let point: CGPoint
    }
    /// After a reset, one thing that made you laugh, if you asked for something lighter.
    @State private var lighter: Laugh?
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()
                switch step {
                case .breathe: breatheStep
                case .pick: pickStep
                case .release: releaseStep
                case .closing: closingStep
                }
            }
            .animation(.calm, value: step)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: fuseCount)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: ripple)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: cloudPuff)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .keyboardDoneButton()
            .onAppear { if pool.isEmpty { pool = ResetWords.pool(loops: loops.map(\.name)) } }
        }
    }

    // MARK: - 1. Breathe

    /// The orb grows as you breathe in and shrinks as you breathe out, with the
    /// words to match and three small dots for the three breaths.
    private var breatheStep: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSince(breathStart)
            let inhaling = ResetWords.isInhaling(at: time)
            let done = min(Int(time / ResetWords.breathLength), 3)
            VStack(spacing: 30) {
                Spacer()
                OrbView(palette: orbPalette, speed: 0.5, state: .breathing, exercise: true)
                    .frame(width: 220, height: 220)
                    .scaleEffect(0.7 + 0.35 * (reduceMotion ? 0.5 : ResetWords.breath(at: time)))
                Text(inhaling ? "breathe in as it grows" : "breathe out as it shrinks")
                    .font(.system(.title3, design: .serif))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.6), value: inhaling)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tint.opacity(0.2)))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Breath \(min(done + 1, 3)) of 3")
                Spacer()
                Text("tap to skip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: inhaling)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { go(.pick) }
        .transition(.opacity)
        .onAppear { breathStart = .now }
        .task {
            // Three breaths, then on to the words.
            try? await Task.sleep(for: .seconds(reduceMotion ? 3 : ResetWords.breathLength * 3 + 0.3))
            if step == .breathe { go(.pick) }
        }
    }

    // MARK: - 2. Pick from floating words

    private var pickStep: some View {
        VStack(spacing: 16) {
            Text("what's in your head?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .padding(.top, 12)

            GeometryReader { proxy in
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let spots = ResetWords.homes(for: pool, in: proxy.size)
                    ZStack {
                        ForEach(Array(pool.enumerated()), id: \.element) { index, word in
                            let home = spots[index]
                            let isPicked = picked.contains(word)
                            Button {
                                withAnimation(.calm) {
                                    if isPicked { picked.removeAll { $0 == word } } else { picked.append(word) }
                                }
                            } label: {
                                Text(word)
                                    .font(.system(.callout, design: .serif))
                                    .foregroundStyle(isPicked ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.75)))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(isPicked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tint.opacity(0.1)), in: Capsule())
                                    .fixedSize()
                            }
                            .buttonStyle(.plain)
                            .position(x: home.x + 10 * sin(t * 0.35 + Double(index) * 1.3),
                                      y: home.y + 8 * cos(t * 0.3 + Double(index) * 0.9))
                            .accessibilityAddTraits(isPicked ? .isSelected : [])
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: picked.count)

            HStack {
                TextField("or a word of your own", text: $own)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit(addOwn)
                if !own.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addOwn).font(.subheadline.weight(.semibold))
                }
            }
            .paperCard(padding: 14)

            Button(picked.isEmpty ? "Skip" : "Next") { go(picked.isEmpty ? .closing : .release) }
                .buttonStyle(.paper)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .transition(.opacity)
    }

    private func addOwn() {
        let word = own.trimmingCharacters(in: .whitespacesAndNewlines)
        own = ""
        typing = false
        guard !word.isEmpty else { return }
        withAnimation(.calm) {
            if !pool.contains(word) { pool.append(word) }
            if !picked.contains(word) { picked.append(word) }
        }
    }

    // MARK: - 3. Water or cloud

    /// Drag each word down into the water to let it go, or up into the cloud
    /// for Sunday. Drop one word onto another and they melt into one thought.
    /// Everything moves softly: words bob while they wait, the water rises a
    /// little to meet a word near it, the cloud glows when one comes close, and
    /// each landing has its own small moment (bubbles, or a puff of the cloud).
    private var releaseStep: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cloudCenter = CGPoint(x: size.width / 2, y: 70)
            let waterTop = size.height - 150
            let live = dragging.flatMap { word in homes(in: size)[word].map { CGPoint(x: $0.x + dragOffset.width, y: $0.y + dragOffset.height) } }
            let nearWater = live.map { $0.y > waterTop - 90 } ?? false
            let nearCloud = live.map { $0.y < cloudCenter.y + 110 } ?? false
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    // The cloud drifts a little, glows when a word comes near, and puffs when it takes one.
                    VStack(spacing: 4) {
                        Cloud()
                            .fill(Color(light: 0xE6EBF2, dark: 0x3A4152))
                            .frame(width: 150, height: 60)
                            .shadow(color: orbPalette.colors[2].opacity(nearCloud ? 0.8 : 0), radius: nearCloud ? 18 : 0)
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                            .scaleEffect(1 + 0.05 * CGFloat(saved.count) + (nearCloud ? 0.05 : 0))
                            .keyframeAnimator(initialValue: 1.0, trigger: cloudPuff) { content, scale in
                                content.scaleEffect(scale)
                            } keyframes: { _ in
                                SpringKeyframe(1.18, duration: 0.25, spring: .bouncy)
                                SpringKeyframe(1.0, duration: 0.6, spring: .smooth)
                            }
                        Text("sunday")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .position(x: cloudCenter.x + 6 * sin(t * 0.25), y: cloudCenter.y + 10 + 3 * sin(t * 0.4))
                    .animation(.spring(duration: 0.4), value: nearCloud)

                    ReleaseWater(color: orbPalette.colors[0], ripple: ripple, rippleX: rippleX, swell: nearWater ? 1 : 0)
                        .frame(height: 170)
                        .overlay(alignment: .bottom) {
                            Text("let go")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.bottom, 30)
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                        .animation(.spring(duration: 0.5), value: nearWater)

                    ForEach(bursts) { burst in
                        BubbleBurst(color: .white)
                            .frame(width: 120, height: 160)
                            .position(burst.point)
                            .allowsHitTesting(false)
                    }

                    let spots = homes(in: size)
                    ForEach(Array(picked.enumerated()), id: \.element) { index, word in
                        if let home = spots[word] {
                            releaseWord(word, home: home, bob: CGFloat(5 * sin(t * 0.9 + Double(index) * 1.7)),
                                        cloud: cloudCenter, waterTop: waterTop, size: size)
                        }
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private var saved: [String] { placed.filter { $0.value == .cloud }.map(\.key) }

    /// Where each waiting word rests: spread across the middle in a soft zigzag.
    private func homes(in size: CGSize) -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        let count = picked.count
        let perRow = min(max(count, 1), 3)
        for (index, word) in picked.enumerated() {
            let row = index / perRow, col = index % perRow
            let inRow = min(perRow, count - row * perRow)
            let x = size.width * CGFloat(col + 1) / CGFloat(inRow + 1)
            let y = size.height * 0.42 + CGFloat(row) * 110 + (col.isMultiple(of: 2) ? -14 : 14)
            result[word] = CGPoint(x: x, y: y)
        }
        return result
    }

    private func releaseWord(_ word: String, home: CGPoint, bob: CGFloat, cloud: CGPoint, waterTop: CGFloat, size: CGSize) -> some View {
        let destination = placed[word]
        let isDragging = dragging == word
        let isFuseTarget = fuseTarget == word
        let target: CGSize = switch destination {
        case .water: CGSize(width: 0, height: waterTop + 70 - home.y)
        case .cloud: CGSize(width: cloud.x - home.x, height: cloud.y - home.y)
        case nil: isDragging ? dragOffset : CGSize(width: 0, height: bob)
        }
        // Stretch a little in the direction it's being pulled, like something soft.
        let stretch = isDragging ? min(hypot(dragOffset.width, dragOffset.height) / 900, 0.12) : 0
        let fused = word.contains(" + ")
        return ZStack {
            MiniOrb(color: fused ? orbPalette.colors[0] : orbPalette.colors[1], seed: Double(word.count))
            Text(word)
                .font(.system(.footnote, design: .serif).weight(.semibold))
                .foregroundStyle(FeelingWords.ink(on: orbPalette))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 12)
        }
        .frame(width: fused ? 110 : 90, height: fused ? 110 : 90)
        .contentShape(Circle())
        .scaleEffect(x: 1 + stretch, y: 1 - stretch * 0.6)
        .scaleEffect(destination == nil ? (isDragging ? 1.1 : isFuseTarget ? 1.15 : 1) : (destination == .water ? 0.5 : 0.2))
        .blur(radius: destination == .water ? 6 : 0)
        .opacity(destination == nil ? 1 : 0)
        .offset(target)
        .position(home)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: isFuseTarget)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard placed[word] == nil else { return }
                    dragging = word
                    dragOffset = value.translation
                    let point = CGPoint(x: home.x + value.translation.width, y: home.y + value.translation.height)
                    fuseTarget = homes(in: size).first { other, spot in
                        other != word && placed[other] == nil && hypot(spot.x - point.x, spot.y - point.y) < 60
                    }?.key
                }
                .onEnded { value in
                    let point = CGPoint(x: home.x + value.translation.width, y: home.y + value.translation.height)
                    if let other = fuseTarget {
                        fuse(word, into: other)
                    } else if point.y > waterTop - 20 {
                        rippleX = min(max(point.x / max(size.width, 1), 0.1), 0.9)
                        bursts.append(Burst(point: CGPoint(x: point.x, y: waterTop + 20)))
                        place(word, .water)
                    } else if point.y < cloud.y + 70 {
                        place(word, .cloud)
                    } else {
                        withAnimation(.spring(duration: 0.6, bounce: 0.4)) { dragOffset = .zero }
                        dragging = nil
                    }
                    fuseTarget = nil
                }
        )
        .allowsHitTesting(destination == nil)
        .zIndex(isDragging ? 10 : 0)
        .accessibilityElement()
        .accessibilityLabel(word)
        .accessibilityHint("Drag down to let it go, or up to save it for Sunday")
        .accessibilityAction(named: "Let it go") { rippleX = home.x / max(size.width, 1); place(word, .water) }
        .accessibilityAction(named: "Save for Sunday") { place(word, .cloud) }
    }

    /// Two words melt into one thought, where the second one was.
    private func fuse(_ word: String, into other: String) {
        withAnimation(.spring(duration: 0.6, bounce: 0.35)) {
            guard let index = picked.firstIndex(of: other) else { return }
            picked[index] = other + " + " + word
            picked.removeAll { $0 == word }
            dragging = nil
            dragOffset = .zero
        }
        fuseCount += 1
    }

    private func place(_ word: String, _ destination: Destination) {
        withAnimation(destination == .water ? .easeIn(duration: 0.9) : .spring(duration: 0.8, bounce: 0.2)) {
            placed[word] = destination
            dragging = nil
            dragOffset = .zero
        }
        if destination == .cloud {
            context.insert(ParkedThought(text: word))
            try? context.save()
            ReminderScheduler.scheduleSundayReview()
            Task {
                try? await Task.sleep(for: .milliseconds(550))
                cloudPuff += 1
            }
        } else {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                ripple += 1
            }
        }
        if picked.allSatisfy({ placed[$0] != nil }) {
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                go(.closing)
            }
        }
    }

    // MARK: - A calm close

    private var closingStep: some View {
        VStack(spacing: 18) {
            Spacer()
            OrbView(palette: orbPalette, state: .settling, ripple: closingRipple)
                .frame(width: 140, height: 140)
                .task { closingRipple += 1 }
            Text(closingMessage)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
            if let lighter {
                LaughCard(laugh: lighter)
                    .paperCard(padding: 14)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if !laughs.isEmpty {
                Button("Want something lighter?", systemImage: "face.smiling") {
                    withAnimation(.calm) { lighter = laughs.randomElement() }
                }
                .font(.subheadline)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.paper)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 28)
        .transition(.opacity)
    }

    private var closingMessage: String {
        if picked.isEmpty { return "You slowed down. That's enough for now." }
        if saved.isEmpty { return "Let go, for now. It can come back, and that's okay." }
        return "Saved for Sunday. You don't have to carry it until then."
    }

    private func go(_ next: Step) {
        withAnimation(.calm) { step = next }
    }
}

/// The words and timings behind "i'm spiraling".
enum ResetWords {
    /// One breath: four seconds in, six out.
    static let breathLength = 10.0

    /// The first four seconds of each breath are breathing in.
    static func isInhaling(at time: Double) -> Bool {
        time.truncatingRemainder(dividingBy: breathLength) < 4
    }

    /// How full the breath is, 0 to 1, at a moment in time.
    static func breath(at time: Double) -> Double {
        func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }
        let phase = time.truncatingRemainder(dividingBy: breathLength)
        return phase < 4 ? ease(phase / 4) : 1 - ease((phase - 4) / 6)
    }

    /// A few heavy words, each a different kind of weight, so none repeat each other.
    static let common = ["not enough", "what if", "too late", "alone", "wasted time", "pressure", "ashamed", "tired"]

    /// The words that drift by: your loops first, then common ones that don't
    /// overlap with them (no "behind" when you have "Falling behind"). Nine at most,
    /// so they fit on screen with room to breathe.
    static func pool(loops: [String], limit: Int = 9) -> [String] {
        var result: [String] = []
        for name in loops.map({ $0.lowercased() }) where !result.contains(name) && result.count < 4 {
            result.append(name)
        }
        let taken = Set(result.flatMap { $0.split(separator: " ").map(String.init) })
        for word in common where result.count < limit {
            let parts = word.split(separator: " ").map(String.init)
            if !result.contains(word) && taken.isDisjoint(with: parts) { result.append(word) }
        }
        return result
    }

    /// About how wide a word's capsule is, so it can be kept on screen.
    static func width(of word: String) -> CGFloat { CGFloat(word.count) * 8.5 + 32 }

    /// A loose, scattered spot for each word, always fully on screen and never
    /// on top of each other: two short words share a row, a long one gets its own.
    static func homes(for words: [String], in size: CGSize) -> [CGPoint] {
        var rows: [[Int]] = []
        for (index, word) in words.enumerated() {
            let wide = width(of: word) > size.width * 0.44
            if let last = rows.last, last.count == 1, !wide, width(of: words[last[0]]) <= size.width * 0.44 {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
            }
        }
        let cellH = size.height / CGFloat(max(rows.count, 1))
        var result = Array(repeating: CGPoint.zero, count: words.count)
        for (r, row) in rows.enumerated() {
            let y = cellH * (CGFloat(r) + 0.5)
            for (c, index) in row.enumerated() {
                let stagger: CGFloat = r.isMultiple(of: 2) ? -0.05 : 0.05
                var x = row.count == 1 ? size.width * (0.5 + stagger * 2) : size.width * ((c == 0 ? 0.27 : 0.73) + stagger)
                let half = width(of: words[index]) / 2 + 12
                x = min(max(x, half), max(half, size.width - half))
                let nudgeY = CGFloat(((index * 53) % 17) - 8) * cellH / 70
                result[index] = CGPoint(x: x, y: y + nudgeY)
            }
        }
        return result
    }
}
