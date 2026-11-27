import SwiftUI

/// "Stop the stream here": after a heavy check-in, the thoughts you just wrote
/// flow down the screen as a stream, each one pulling the next along a little
/// faster. Drag a line across it and stones drop in, one by one, into a small dam.
/// Below it the water slows and clears. Above it the words gather in a still pool
/// instead of rushing on.
///
/// Nothing is deleted or pushed away (pushing thoughts away tends to bring them
/// back stronger). The words are still in your journal. It's a pause, not a fight.
struct StreamDamView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let words: [String]
    let onDone: () -> Void

    @State private var start = Date.now
    /// When the dam went in, and where (as a share of the height).
    @State private var damAt: Date?
    @State private var damY: CGFloat = 0.55
    /// The line you're drawing across the stream.
    @State private var drawn: [CGPoint] = []
    @State private var stones = 0
    @State private var showCue = false

    private static let stoneCount = 9

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && damAt == nil)) { timeline in
                let now = timeline.date
                let t = now.timeIntervalSince(start)
                let settle = damAt.map { min(now.timeIntervalSince($0) / 2.2, 1) } ?? 0
                ZStack {
                    Canvas { ctx, canvasSize in
                        StreamDrawing.draw(in: &ctx, size: canvasSize, t: reduceMotion ? 0 : t,
                                           damY: damAt == nil ? nil : damY * canvasSize.height,
                                           settle: StreamDrawing.ease(settle))
                    }
                    ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                        let p = StreamDrawing.wordPosition(index: i, count: words.count, size: size, t: t,
                                                           damAt: damAt.map { $0.timeIntervalSince(start) },
                                                           damY: damY * size.height, now: t)
                        Text(word)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.background.opacity(0.92), in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                            .rotationEffect(.degrees(p.tilt))
                            .opacity(p.opacity)
                            .position(p.point)
                    }
                    // The stones, dropping in one at a time.
                    if damAt != nil {
                        ForEach(0..<Self.stoneCount, id: \.self) { i in
                            let spot = StreamDrawing.stoneSpot(i, of: Self.stoneCount, damY: damY * size.height, size: size)
                            Stone(seed: i)
                                .frame(width: spot.size.width, height: spot.size.height)
                                .position(spot.center)
                                .offset(y: i < stones ? 0 : -size.height * 0.6)
                                .opacity(i < stones ? 1 : 0)
                                .animation(.spring(duration: 0.55, bounce: 0.35), value: stones)
                        }
                    }
                    // The line as you draw it, like a finger through wet sand.
                    if drawn.count > 1 {
                        Path { $0.addLines(drawn) }
                            .stroke(.primary.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 6]))
                    }
                    if showCue && damAt == nil && drawn.isEmpty {
                        SwipeAcrossCue(y: size.height * 0.55, width: size.width)
                            .transition(.opacity)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(drawGesture(size: size), including: damAt == nil ? .all : .subviews)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            if stones >= Self.stoneCount {
                VStack(spacing: 14) {
                    Text("The stream can wait here.")
                        .font(.system(.title3, design: .serif))
                    Button("Done", action: onDone)
                        .buttonStyle(.paper)
                        .frame(maxWidth: 220)
                }
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.calm, value: stones >= Self.stoneCount)
        .background(ThemeBackground())
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.6), trigger: stones)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.calm) { showCue = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Stop the stream") { placeDam(at: 0.55) }
    }

    private func drawGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drawn.append($0.location) }
            .onEnded { _ in
                let points = drawn
                drawn = []
                guard StreamDrawing.crossesStream(points, size: size) else { return }
                let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
                placeDam(at: min(max(y / size.height, 0.3), 0.8))
            }
    }

    private func placeDam(at share: CGFloat) {
        guard damAt == nil else { return }
        damY = share
        damAt = .now
        showCue = false
        Task {
            for _ in 0..<Self.stoneCount {
                stones += 1
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 160))
            }
        }
    }
}

/// A smooth river stone, a little different each time.
private struct Stone: View {
    let seed: Int

    var body: some View {
        let tone = Double((seed * 37) % 10) / 10
        Ellipse()
            .fill(LinearGradient(colors: [Color(light: 0xB9B2A6, dark: 0x8A847A).mix(with: .white, by: 0.15 * tone),
                                          Color(light: 0x8E877C, dark: 0x5E5952)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Ellipse().stroke(.white.opacity(0.35), lineWidth: 1).padding(2).offset(x: -1, y: -1))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
            .rotationEffect(.degrees(Double((seed * 53) % 30) - 15))
    }
}

/// A faint hand that sweeps across the stream, once in a while, until you try it.
private struct SwipeAcrossCue: View {
    let y: CGFloat
    let width: CGFloat
    @State private var sweep = false

    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.title)
            .foregroundStyle(.secondary)
            .position(x: sweep ? width * 0.8 : width * 0.2, y: y + 24)
            .opacity(sweep ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) { sweep = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The geometry and drawing of the stream, kept apart so it can be tested.
enum StreamDrawing {
    static func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }

    /// The middle of the stream at a height: a slow, gentle meander.
    static func centerX(y: CGFloat, size: CGSize) -> CGFloat {
        size.width / 2 + sin(y / 130) * size.width * 0.08
    }

    static func width(size: CGSize) -> CGFloat { min(size.width * 0.42, 190) }

    /// True when a drawn line runs across most of the stream.
    static func crossesStream(_ points: [CGPoint], size: CGSize) -> Bool {
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return false }
        let y = (minY + maxY) / 2
        let center = centerX(y: y, size: size)
        let half = width(size: size) / 2
        let covers = minX <= center - half * 0.6 && maxX >= center + half * 0.6
        // Mostly sideways, not a scroll or a tap.
        return covers && (maxY - minY) < (maxX - minX) * 0.8
    }

    /// How far a word has travelled: it starts gently and speeds up, the way one
    /// thought pulls the next, up to a limit.
    static func travelled(_ t: Double) -> Double {
        let ramp = 14.0
        let v0 = 38.0, a = 4.0
        let tr = min(t, ramp)
        return v0 * t + 0.5 * a * tr * tr + a * ramp * max(t - ramp, 0)
    }

    struct WordSpot { var point: CGPoint; var opacity: Double; var tilt: Double }

    /// Where a word is. Before the dam it flows down, looping from the top.
    /// After, words above the dam drift into a still pool just above it; words
    /// already past it carry on downstream and fade.
    static func wordPosition(index i: Int, count: Int, size: CGSize, t: Double,
                             damAt: Double?, damY: CGFloat, now: Double) -> WordSpot {
        let loop = Double(size.height) + 80
        let spacing = loop / Double(max(count, 1))
        func flowingY(_ time: Double) -> CGFloat {
            CGFloat((travelled(time) + Double(i) * spacing).truncatingRemainder(dividingBy: loop)) - 40
        }
        func flowing(_ time: Double) -> CGPoint {
            let y = flowingY(time)
            let sway = sin(time * 0.8 + Double(i) * 1.7) * Double(width(size: size)) * 0.22
            return CGPoint(x: centerX(y: y, size: size) + CGFloat(sway), y: y)
        }
        guard let damAt else {
            return WordSpot(point: flowing(t), opacity: 1, tilt: sin(t + Double(i)) * 4)
        }
        let at = flowing(damAt)
        if at.y > damY {
            // Already past the dam: carried on down and away.
            let y = at.y + CGFloat(travelled(t) - travelled(damAt)) * 0.5
            let fade = max(0, 1 - Double(y - at.y) / 220)
            return WordSpot(point: CGPoint(x: centerX(y: y, size: size), y: y), opacity: fade, tilt: 0)
        }
        // Gathering in the pool: a slot above the dam, then a slow bob.
        let row = i % 3, ring = i / 3
        let pool = CGPoint(x: size.width / 2 + CGFloat(row - 1) * min(size.width * 0.28, 120),
                           y: damY - 60 - CGFloat(ring) * 46)
        let k = ease(min((t - damAt) / 2.2, 1))
        let bob = CGFloat(sin(t * 0.9 + Double(i))) * 3
        let p = CGPoint(x: at.x + (pool.x - at.x) * k, y: at.y + (pool.y - at.y) * k + bob * k)
        return WordSpot(point: p, opacity: 1, tilt: sin(t * 0.5 + Double(i)) * 2 * k)
    }

    /// Where each stone sits: a slightly bowed line across the stream.
    static func stoneSpot(_ i: Int, of n: Int, damY: CGFloat, size: CGSize) -> (center: CGPoint, size: CGSize) {
        let span = width(size: size) * 1.25
        let center = centerX(y: damY, size: size)
        let x = center - span / 2 + span * CGFloat(i) / CGFloat(max(n - 1, 1))
        let bow = sin(Double(i) / Double(max(n - 1, 1)) * .pi) * 6
        let w = CGFloat(30 + (i * 7) % 12), h = CGFloat(20 + (i * 5) % 8)
        return (CGPoint(x: x, y: damY + CGFloat(bow) + (i.isMultiple(of: 2) ? 0 : -6)), CGSize(width: w, height: h))
    }

    static let water = Color(light: 0x8FBFCB, dark: 0x3F6F7C)
    static let calm = Color(light: 0xCFE6EB, dark: 0x2B4A52)

    /// The river: a band of water with streaks flowing down. Once dammed, it widens
    /// into a still pool above the stones and runs slow and clear below them.
    static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, damY: CGFloat?, settle: Double) {
        let half = width(size: size) / 2
        func halfWidth(at y: CGFloat) -> CGFloat {
            guard let damY else { return half }
            // The pool: wider just above the dam, easing back to the stream higher up.
            let d = damY - y
            let pool = d > 0 && d < 260 ? sin(Double(d) / 260 * .pi) * Double(size.width) * 0.2 : 0
            return half + CGFloat(pool * settle)
        }
        var band = Path()
        let step: CGFloat = 8
        var left: [CGPoint] = [], right: [CGPoint] = []
        for y in stride(from: CGFloat(-10), through: size.height + 10, by: step) {
            let c = centerX(y: y, size: size)
            let w = halfWidth(at: y) + CGFloat(sin(Double(y) / 40 + t * 0.7)) * 3
            left.append(CGPoint(x: c - w, y: y))
            right.append(CGPoint(x: c + w, y: y))
        }
        band.addLines(left)
        band.addLines(right.reversed())
        band.closeSubpath()
        ctx.fill(band, with: .linearGradient(Gradient(colors: [water.opacity(0.55), water.opacity(0.75)]),
                                             startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        // Below the dam the water clears and calms.
        if let damY {
            ctx.drawLayer { layer in
                layer.clip(to: band)
                layer.fill(Path(CGRect(x: 0, y: damY, width: size.width, height: size.height - damY)),
                           with: .color(calm.opacity(0.85 * settle)))
                // The still pool above takes a soft, glassy sheen.
                layer.fill(Path(CGRect(x: 0, y: damY - 260, width: size.width, height: 260)),
                           with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.18 * settle)]),
                                                 startPoint: CGPoint(x: 0, y: damY - 260), endPoint: CGPoint(x: 0, y: damY)))
            }
        }

        // Streaks of current. Fast before the dam; still in the pool; slow below.
        for i in 0..<26 {
            let lane = (Double(i) * 0.618).truncatingRemainder(dividingBy: 1) * 2 - 1
            var speed = 90.0 + Double(i % 5) * 18
            let loop = Double(size.height) + 60
            var y = CGFloat((t * speed + Double(i) * 97).truncatingRemainder(dividingBy: loop)) - 30
            var alpha = 0.5
            if let damY {
                if y < damY {
                    alpha *= 1 - settle            // the pool goes still
                } else {
                    speed *= 1 - 0.75 * settle     // slower downstream
                    y = CGFloat((t * speed + Double(i) * 97).truncatingRemainder(dividingBy: loop)) - 30
                    if y < damY { continue }
                    alpha *= 1 - 0.5 * settle
                }
            }
            let x = centerX(y: y, size: size) + CGFloat(lane) * half * 0.75
            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addLine(to: CGPoint(x: x, y: y + 14 + CGFloat(i % 3) * 6))
            ctx.stroke(streak, with: .color(.white.opacity(alpha)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // Rings on the still pool.
        if let damY, settle > 0 {
            for i in 0..<3 {
                let phase = (t * 0.25 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let r = 10 + 60 * phase
                let c = CGPoint(x: centerX(y: damY - 120, size: size) + CGFloat(i - 1) * 40, y: damY - 120 + CGFloat(i) * 30)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.4, width: r * 2, height: r * 0.8)),
                           with: .color(.white.opacity(0.35 * (1 - phase) * settle)), lineWidth: 1)
            }
        }
    }
}

/// The thoughts to put in the stream: the words you kept, or short pieces of what
/// you wrote, or (for a drawing) your loop and a few common ones.
enum StreamWords {
    static let limit = 8

    static func pieces(text: String, kind: EntryKind, loop: String?) -> [String] {
        var result: [String] = []
        if kind == .words {
            result = FeelingWords.parse(text).map(\.word)
        } else if kind.isText {
            let separators = CharacterSet(charactersIn: ".,;!?\n—")
            let chunks = text.components(separatedBy: separators)
                .flatMap { $0.components(separatedBy: " but ") }
                .flatMap { $0.components(separatedBy: " and ") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for chunk in chunks {
                let words = chunk.split(separator: " ")
                let short = words.prefix(4).joined(separator: " ") + (words.count > 4 ? "…" : "")
                if !result.contains(where: { $0.caseInsensitiveCompare(short) == .orderedSame }) { result.append(short) }
            }
        }
        if let loop, !loop.isEmpty, !result.contains(where: { $0.caseInsensitiveCompare(loop) == .orderedSame }) {
            result.append(loop.lowercased())
        }
        for word in ResetWords.common where result.count < 4 && !result.contains(word) {
            result.append(word)
        }
        return Array(result.prefix(limit))
    }
}
