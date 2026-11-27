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

    private var breatheStep: some View {
        VStack(spacing: 30) {
            Spacer()
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let scale = reduceMotion ? 1 : ResetWords.breath(at: timeline.date.timeIntervalSinceReferenceDate)
                OrbView(palette: orbPalette, speed: 0.5, state: .breathing, exercise: true)
                    .frame(width: 220, height: 220)
                    .scaleEffect(0.75 + 0.3 * scale)
            }
            Text("slow down with me")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(.secondary)
            Spacer()
            Text("tap to skip")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { go(.pick) }
        .transition(.opacity)
        .task {
            // Three breaths, then on to the words.
            try? await Task.sleep(for: .seconds(reduceMotion ? 3 : ResetWords.breathLength * 3))
            if step == .breathe { go(.pick) }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: step)
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
                    ZStack {
                        ForEach(Array(pool.enumerated()), id: \.element) { index, word in
                            let home = ResetWords.home(index: index, count: pool.count, in: proxy.size)
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

    private var releaseStep: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cloudCenter = CGPoint(x: size.width / 2, y: 70)
            let waterTop = size.height - 150
            ZStack {
                // The cloud: a little fuller for each thought it holds.
                VStack(spacing: 4) {
                    Cloud()
                        .fill(Color(light: 0xE6EBF2, dark: 0x3A4152))
                        .frame(width: 150, height: 60)
                        .scaleEffect(1 + 0.06 * CGFloat(saved.count))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    Text("sunday")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .position(x: cloudCenter.x, y: cloudCenter.y + 10)

                ReleaseWater(color: orbPalette.colors[0], ripple: ripple, rippleX: rippleX)
                    .frame(height: 150)
                    .overlay(alignment: .bottom) {
                        Text("let go")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 30)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)

                ForEach(Array(picked.enumerated()), id: \.element) { index, word in
                    let home = CGPoint(x: size.width * CGFloat(index + 1) / CGFloat(picked.count + 1),
                                       y: size.height * 0.45 + (index.isMultiple(of: 2) ? -16 : 16))
                    releaseWord(word, home: home, cloud: cloudCenter, waterTop: waterTop, width: size.width)
                }
            }
        }
        .transition(.opacity)
    }

    private var saved: [String] { placed.filter { $0.value == .cloud }.map(\.key) }

    private func releaseWord(_ word: String, home: CGPoint, cloud: CGPoint, waterTop: CGFloat, width: CGFloat) -> some View {
        let destination = placed[word]
        let live = dragging == word ? dragOffset : .zero
        let target: CGSize = switch destination {
        case .water: CGSize(width: 0, height: waterTop + 60 - home.y)
        case .cloud: CGSize(width: cloud.x - home.x, height: cloud.y - home.y)
        case nil: live
        }
        return ZStack {
            MiniOrb(color: orbPalette.colors[1], seed: Double(word.count))
            Text(word)
                .font(.system(.footnote, design: .serif).weight(.semibold))
                .foregroundStyle(FeelingWords.ink(on: orbPalette))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 10)
        }
        .frame(width: 86, height: 86)
        .contentShape(Circle())
        .scaleEffect(destination == nil ? (dragging == word ? 1.1 : 1) : 0.25)
        .opacity(destination == nil ? 1 : 0)
        .offset(target)
        .position(home)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard placed[word] == nil else { return }
                    dragging = word
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let y = home.y + value.translation.height
                    if y > waterTop {
                        rippleX = min(max((home.x + value.translation.width) / max(width, 1), 0.1), 0.9)
                        place(word, .water)
                    } else if y < cloud.y + 50 {
                        place(word, .cloud)
                    } else {
                        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { dragOffset = .zero }
                        dragging = nil
                    }
                }
        )
        .allowsHitTesting(destination == nil)
        .accessibilityElement()
        .accessibilityLabel(word)
        .accessibilityHint("Drag down to let it go, or up to save it for Sunday")
        .accessibilityAction(named: "Let it go") { rippleX = home.x / max(width, 1); place(word, .water) }
        .accessibilityAction(named: "Save for Sunday") { place(word, .cloud) }
    }

    private func place(_ word: String, _ destination: Destination) {
        withAnimation(.easeIn(duration: 0.6)) {
            placed[word] = destination
            dragging = nil
            dragOffset = .zero
        }
        if destination == .cloud {
            context.insert(ParkedThought(text: word))
            try? context.save()
            ReminderScheduler.scheduleSundayReview()
        } else {
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                ripple += 1
            }
        }
        if picked.allSatisfy({ placed[$0] != nil }) {
            Task {
                try? await Task.sleep(for: .seconds(1.4))
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

    /// How full the breath is, 0 to 1, at a moment in time.
    static func breath(at time: Double) -> Double {
        func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }
        let phase = time.truncatingRemainder(dividingBy: breathLength)
        return phase < 4 ? ease(phase / 4) : 1 - ease((phase - 4) / 6)
    }

    /// The heavy words that drift by: your loops, then a few common ones, about a dozen in all.
    static func pool(loops: [String], extra: Int = 12) -> [String] {
        let common = ["behind", "not enough", "wasted time", "what if", "alone", "failing",
                      "too late", "should", "overwhelmed", "stuck", "unsure", "pressure", "tired", "ashamed"]
        var result: [String] = []
        for word in loops.map({ $0.lowercased() }) + common where !result.contains(word) {
            result.append(word)
            if result.count >= max(extra, min(loops.count, 6) + 6) { break }
        }
        return result
    }

    /// A loose, scattered spot for each word, so they never line up like a list.
    static func home(index: Int, count: Int, in size: CGSize) -> CGPoint {
        let columns = 3
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let col = index % columns, row = index / columns
        let cellW = size.width / CGFloat(columns), cellH = size.height / CGFloat(rows)
        // A small, steady nudge per word so the grid doesn't show.
        let nudgeX = CGFloat(((index * 37) % 21) - 10) * cellW / 60
        let nudgeY = CGFloat(((index * 53) % 17) - 8) * cellH / 50
        let stagger = row.isMultiple(of: 2) ? -cellW * 0.12 : cellW * 0.12
        return CGPoint(x: cellW * (CGFloat(col) + 0.5) + stagger + nudgeX,
                       y: cellH * (CGFloat(row) + 0.5) + nudgeY)
    }
}
