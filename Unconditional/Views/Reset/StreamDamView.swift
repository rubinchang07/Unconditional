import SwiftUI

// MARK: - Order the words into a stream

/// Before the stream: put the words you picked in the order they come, one
/// leading to the next (by intensity, or however feels right). Drag to reorder.
/// A faint line of water runs through them, so it already looks like a stream.
struct StreamOrderView: View {
    @Binding var words: [String]
    let onNext: () -> Void
    @State private var dragging: String?
    @State private var dragY: CGFloat = 0
    /// How much of the drag has already been spent moving the word past others.
    @State private var consumed: CGFloat = 0

    private let rowHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 16) {
            Text("how does it flow?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .padding(.top, 12)
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                // The stream so far: a soft line through every word.
                Capsule()
                    .fill(StreamDrawing.water.opacity(0.45))
                    .frame(width: 10, height: max(rowHeight * CGFloat(words.count - 1), 0))
                    .padding(.top, rowHeight / 2)
                ForEach(Array(words.enumerated()), id: \.element) { index, word in
                    let isDragging = dragging == word
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(word)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.background, in: Capsule())
                    .overlay(Capsule().stroke(StreamDrawing.water.opacity(0.6), lineWidth: 1))
                    .shadow(color: .black.opacity(isDragging ? 0.18 : 0.06), radius: isDragging ? 10 : 4, y: 2)
                    .scaleEffect(isDragging ? 1.06 : 1)
                    .frame(height: rowHeight)
                    .offset(y: rowHeight * CGFloat(index) + (isDragging ? dragY : 0))
                    .zIndex(isDragging ? 1 : 0)
                    .gesture(reorder(word))
                    .accessibilityLabel("\(index + 1): \(word)")
                    .accessibilityAction(named: "Move up") { move(word, by: -1) }
                    .accessibilityAction(named: "Move down") { move(word, by: 1) }
                }
            }
            .frame(height: rowHeight * CGFloat(words.count), alignment: .top)
            .animation(.spring(duration: 0.35, bounce: 0.25), value: words)
            .sensoryFeedback(.selection, trigger: words)
            Spacer(minLength: 0)
            Button("Next", action: onNext)
                .buttonStyle(.paper)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }

    /// Drag a word up or down; the others make room as it passes them.
    private func reorder(_ word: String) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard let current = words.firstIndex(of: word) else { return }
                dragging = word
                dragY = value.translation.height - consumed
                let target = min(max(current + Int((dragY / rowHeight).rounded()), 0), words.count - 1)
                if target != current {
                    words.move(fromOffsets: IndexSet(integer: current), toOffset: target > current ? target + 1 : target)
                    consumed += rowHeight * CGFloat(target - current)
                    dragY = value.translation.height - consumed
                }
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.35, bounce: 0.3)) { dragY = 0 }
                consumed = 0
                dragging = nil
            }
    }

    private func move(_ word: String, by step: Int) {
        guard let i = words.firstIndex(of: word) else { return }
        let target = min(max(i + step, 0), words.count - 1)
        guard target != i else { return }
        words.move(fromOffsets: IndexSet(integer: i), toOffset: target > i ? target + 1 : target)
    }
}

// MARK: - The stream and the dam

/// Your words sit still along a stream, in the order you gave them, while the water
/// runs past them. Drag a line across, between two words, and stones drop in one by
/// one into a small dam. Above it the water stops and becomes a still pool around
/// the words before the dam. Below it the water drains away, and the words there
/// stay where they were, faded on the dry bed: the part of the spiral you cut off.
///
/// Nothing is deleted or pushed away (pushing thoughts away tends to bring them
/// back stronger). It's a pause, not a fight.
struct StreamDamView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let words: [String]
    /// Move on by itself a moment after the dam is built.
    var autoContinue = true
    /// The words above the dam, the ones still with you.
    let onDone: ([String]) -> Void

    @State private var start = Date.now
    @State private var damAt: Date?
    /// The dam sits just above this word; it and everything after it are cut off.
    @State private var cutIndex = 0
    @State private var drawn: [CGPoint] = []
    @State private var stones = 0
    @State private var showCue = false

    private static let stoneCount = 9

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let spots = StreamDrawing.wordSpots(count: words.count, size: size)
            let damY = StreamDrawing.damY(cut: cutIndex, spots: spots, size: size)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && damAt == nil)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
                let settle = damAt.map { StreamDrawing.ease(min(timeline.date.timeIntervalSince($0) / 2.2, 1)) } ?? 0
                ZStack {
                    Canvas { ctx, canvasSize in
                        StreamDrawing.draw(in: &ctx, size: canvasSize, t: t,
                                           damY: damAt == nil ? nil : damY, settle: settle)
                    }
                    ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                        let cut = damAt != nil && i >= cutIndex
                        let bob = CGFloat(sin(t * 0.9 + Double(i) * 1.7)) * (cut ? 3 * (1 - settle) : 3)
                        Text(word)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(cut ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.background.opacity(cut ? 0.55 : 0.92), in: Capsule())
                            .shadow(color: .black.opacity(cut ? 0 : 0.12), radius: 4, y: 2)
                            .saturation(cut ? 0 : 1)
                            .opacity(cut ? 1 - 0.45 * settle : 1)
                            .rotationEffect(.degrees(sin(t * 0.6 + Double(i)) * 2))
                            .position(x: spots[i].x, y: spots[i].y + bob)
                    }
                    if damAt != nil {
                        ForEach(0..<Self.stoneCount, id: \.self) { i in
                            let spot = StreamDrawing.stoneSpot(i, of: Self.stoneCount, damY: damY, size: size)
                            Stone(seed: i)
                                .frame(width: spot.size.width, height: spot.size.height)
                                .position(spot.center)
                                .offset(y: i < stones ? 0 : -size.height * 0.6)
                                .opacity(i < stones ? 1 : 0)
                                .animation(.spring(duration: 0.55, bounce: 0.35), value: stones)
                        }
                    }
                    if drawn.count > 1 {
                        Path { $0.addLines(drawn) }
                            .stroke(.primary.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 6]))
                    }
                    if showCue && damAt == nil && drawn.isEmpty {
                        SwipeAcrossCue(y: StreamDrawing.damY(cut: max(words.count / 2, 1), spots: spots, size: size),
                                       width: size.width)
                            .transition(.opacity)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(drawGesture(size: size, spots: spots), including: damAt == nil ? .all : .subviews)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Dam the stream here") { placeDam(cut: max(words.count / 2, 1)) }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.6), trigger: stones)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.calm) { showCue = true }
        }
    }

    private func drawGesture(size: CGSize, spots: [CGPoint]) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drawn.append($0.location) }
            .onEnded { _ in
                let points = drawn
                drawn = []
                guard StreamDrawing.crossesStream(points, size: size) else { return }
                let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
                placeDam(cut: StreamDrawing.cutIndex(atY: y, spots: spots))
            }
    }

    private func placeDam(cut: Int) {
        guard damAt == nil else { return }
        cutIndex = cut
        damAt = .now
        showCue = false
        Task {
            for _ in 0..<Self.stoneCount {
                stones += 1
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 160))
            }
            if autoContinue {
                // Long enough to watch the pool still and the cut-off words fade on the dry bed.
                try? await Task.sleep(for: .seconds(2.8))
                onDone(Array(words.prefix(cutIndex)))
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
    static let water = Color(light: 0x8FBFCB, dark: 0x3F6F7C)
    /// The dry bed below the dam.
    static let dry = Color(light: 0xE8DFD0, dark: 0x2E2A25)

    static func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }

    /// The middle of the stream at a height: a slow, gentle meander.
    static func centerX(y: CGFloat, size: CGSize) -> CGFloat {
        size.width / 2 + sin(y / 130) * size.width * 0.08
    }

    static func width(size: CGSize) -> CGFloat { min(size.width * 0.42, 190) }

    /// Where each word sits, first at the top, evenly down the stream, a little
    /// to one side and then the other.
    static func wordSpots(count: Int, size: CGSize) -> [CGPoint] {
        guard count > 0 else { return [] }
        let top = size.height * 0.14, bottom = size.height * 0.86
        let gap = count == 1 ? 0 : (bottom - top) / CGFloat(count - 1)
        return (0..<count).map { i in
            let y = count == 1 ? size.height / 2 : top + gap * CGFloat(i)
            let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
            return CGPoint(x: centerX(y: y, size: size) + side * width(size: size) * 0.16, y: y)
        }
    }

    /// Which word the dam goes just above, for a line drawn at `y`:
    /// 0 cuts off everything, `count` cuts off nothing.
    static func cutIndex(atY y: CGFloat, spots: [CGPoint]) -> Int {
        spots.firstIndex { $0.y > y } ?? spots.count
    }

    /// The dam's height: halfway between the last word kept and the first one cut off.
    static func damY(cut: Int, spots: [CGPoint], size: CGSize) -> CGFloat {
        guard !spots.isEmpty else { return size.height / 2 }
        let above = cut > 0 ? spots[cut - 1].y : size.height * 0.04
        let below = cut < spots.count ? spots[cut].y : size.height * 0.96
        return (above + below) / 2
    }

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

    /// Where each stone sits: a slightly bowed line across the stream.
    static func stoneSpot(_ i: Int, of n: Int, damY: CGFloat, size: CGSize) -> (center: CGPoint, size: CGSize) {
        let span = width(size: size) * 1.25
        let center = centerX(y: damY, size: size)
        let x = center - span / 2 + span * CGFloat(i) / CGFloat(max(n - 1, 1))
        let bow = sin(Double(i) / Double(max(n - 1, 1)) * .pi) * 6
        let w = CGFloat(30 + (i * 7) % 12), h = CGFloat(20 + (i * 5) % 8)
        return (CGPoint(x: x, y: damY + CGFloat(bow) + (i.isMultiple(of: 2) ? 0 : -6)), CGSize(width: w, height: h))
    }

    /// The stream: a band of water with streaks of current running down past the
    /// words. Once dammed, the water above goes still and widens a little into a
    /// pool; below, it drains to a dry bed.
    static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, damY: CGFloat?, settle: Double) {
        let half = width(size: size) / 2
        func halfWidth(at y: CGFloat) -> CGFloat {
            guard let damY else { return half }
            let d = damY - y
            let pool = d > 0 && d < 220 ? sin(Double(d) / 220 * .pi) * Double(size.width) * 0.12 : 0
            return half + CGFloat(pool * settle)
        }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for y in stride(from: CGFloat(-10), through: size.height + 10, by: 8) {
            let c = centerX(y: y, size: size)
            let w = halfWidth(at: y) + CGFloat(sin(Double(y) / 40 + t * 0.7)) * 3
            left.append(CGPoint(x: c - w, y: y))
            right.append(CGPoint(x: c + w, y: y))
        }
        var band = Path()
        band.addLines(left)
        band.addLines(right.reversed())
        band.closeSubpath()
        ctx.fill(band, with: .linearGradient(Gradient(colors: [water.opacity(0.55), water.opacity(0.75)]),
                                             startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        if let damY {
            ctx.drawLayer { layer in
                layer.clip(to: band)
                // Below: the water drains away to a dry, pale bed.
                layer.fill(Path(CGRect(x: 0, y: damY, width: size.width, height: size.height - damY)),
                           with: .color(dry.opacity(0.95 * settle)))
                // Above: a still, glassy pool.
                layer.fill(Path(CGRect(x: 0, y: damY - 220, width: size.width, height: 220)),
                           with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.2 * settle)]),
                                                 startPoint: CGPoint(x: 0, y: damY - 220), endPoint: CGPoint(x: 0, y: damY)))
            }
        }

        // Streaks of current, running past the words. They stop once the dam is in.
        let loop = Double(size.height) + 60
        for i in 0..<26 {
            let lane = (Double(i) * 0.618).truncatingRemainder(dividingBy: 1) * 2 - 1
            let speed = 70.0 + Double(i % 5) * 16
            let y = CGFloat((t * speed + Double(i) * 97).truncatingRemainder(dividingBy: loop)) - 30
            var alpha = 0.5
            if let damY { alpha *= y < damY ? 1 - settle : 0 }
            guard alpha > 0.01 else { continue }
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
                let r = 10 + 50 * phase
                let c = CGPoint(x: centerX(y: damY - 90, size: size) + CGFloat(i - 1) * 36, y: damY - 110 + CGFloat(i) * 26)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.4, width: r * 2, height: r * 0.8)),
                           with: .color(.white.opacity(0.35 * (1 - phase) * settle)), lineWidth: 1)
            }
        }
    }
}
