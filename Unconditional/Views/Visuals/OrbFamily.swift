import SwiftUI

// The orb's family: smaller orbs that split off, merge back, float, and glow.
// They share the main orb's softness so the whole app speaks one visual language.

// MARK: - Gooey drawing

/// One round shape in a gooey group.
struct GooeyBlob {
    var center: CGPoint
    var radius: CGFloat
    var color: Color
}

enum Gooey {
    /// Draws blobs so that nearby ones melt together like liquid.
    ///
    /// How it works: everything is blurred, then an alpha threshold turns the
    /// blur back into a crisp edge. Where two blurs overlap, their combined
    /// alpha passes the threshold, so a soft bridge forms between them and
    /// pinches off as they move apart. Colored light is then drawn on top.
    static func draw(_ blobs: [GooeyBlob], in context: GraphicsContext, base: Color, blur: CGFloat = 14) {
        var silhouette = context
        silhouette.opacity = 0.55
        silhouette.addFilter(.alphaThreshold(min: 0.5, color: base))
        silhouette.addFilter(.blur(radius: blur))
        silhouette.drawLayer { layer in
            for blob in blobs where blob.radius > 0.5 {
                layer.fill(Circle().path(in: rect(blob.center, blob.radius)), with: .color(.black))
            }
        }
        for blob in blobs where blob.radius > 0.5 {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: blob.radius * 0.25))
                layer.fill(Circle().path(in: rect(blob.center, blob.radius * 0.88)),
                           with: .radialGradient(Gradient(colors: [blob.color.opacity(0.95), blob.color.opacity(0.55)]),
                                                 center: CGPoint(x: blob.center.x - blob.radius * 0.25, y: blob.center.y - blob.radius * 0.3),
                                                 startRadius: 0, endRadius: blob.radius * 1.2))
            }
        }
    }

    static func rect(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    /// Smoothstep from 0 to 1.
    static func ease(_ x: Double) -> Double {
        let p = min(1, max(0, x))
        return p * p * (3 - 2 * p)
    }
}

// MARK: - A small undulating orb

/// A little orb with the same soft, wobbly edge as the big one. Used for loops.
struct MiniOrb: View {
    let color: Color
    var seed: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = (min(size.width, size.height) - Self.bleed * 2) / 2 * 0.86
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.2))
                    layer.fill(OrbView.blob(center: center, radius: radius, time: t * 0.6, seed: seed, wobble: 0.8),
                               with: .color(color.opacity(0.45)))
                }
                ctx.fill(OrbView.blob(center: center, radius: radius * 0.92, time: t * 0.8, seed: seed + 1, wobble: 0.7),
                         with: .radialGradient(Gradient(colors: [color.opacity(0.7), color]),
                                               center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.35),
                                               startRadius: 0, endRadius: radius * 1.3))
            }
            // Like the big orb: the canvas spills past its frame so the soft glow
            // isn't clipped into a square.
            .padding(-Self.bleed)
        }
        .accessibilityHidden(true)
    }

    private static let bleed: CGFloat = 30
}

// MARK: - The orb divides into your values

/// Hold the orb on Today and it gently divides into one small orb per value,
/// all the same size, because a value doesn't shrink in a hard week. Tap one to read it. Tap the
/// middle to let them flow back together.
struct ValuesBloom: View {
    let values: [PersonalValue]
    let palette: OrbPalette
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openedAt = Date.now
    @State private var closingAt: Date?
    @State private var selected: PersonalValue?

    private let openDuration = 1.3
    private let closeDuration = 0.9
    private let bleed: CGFloat = 70

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let size = proxy.size
                TimelineView(.animation(paused: reduceMotion && closingAt == nil)) { timeline in
                    let p = progress(at: timeline.date)
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Canvas { ctx, canvasSize in
                            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                            Gooey.draw(blobs(center: center, size: size, p: p, t: t), in: ctx, base: palette.colors[0])
                        }
                        .padding(-bleed)

                        // Names and tap targets sit on top of the drawing.
                        ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                            let point = position(index, center: CGPoint(x: size.width / 2, y: size.height / 2), size: size, p: p, t: t)
                            let r = smallRadius(value, size: size, p: p)
                            Button { withAnimation(.calm) { selected = value } } label: {
                                Color.clear.frame(width: r * 2 + 12, height: r * 2 + 12).contentShape(Circle())
                            }
                            .position(point)
                            .accessibilityLabel(value.name)
                            Text(value.name)
                                .font(.caption.weight(selected == value ? .semibold : .regular))
                                .foregroundStyle(selected == value ? .primary : .secondary)
                                .fixedSize()
                                .position(x: point.x, y: point.y + r + 12)
                                .opacity(p)
                                .allowsHitTesting(false)
                        }

                        // Tap the middle to bring everything back together.
                        Button(action: close) {
                            Color.clear.frame(width: 80, height: 80).contentShape(Circle())
                        }
                        .accessibilityLabel("Bring them back together")
                    }
                }
            }

            Group {
                if values.isEmpty {
                    Text("Add values in Anchors, and they'll live inside the orb.")
                } else if let selected {
                    VStack(spacing: 4) {
                        Text(selected.name).font(.system(.headline, design: .serif))
                        if !selected.meaning.isEmpty { Text(selected.meaning) }
                    }
                } else {
                    Text("These are part of you, on good days and hard ones. Tap one, or tap the middle to bring them back.")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(minHeight: 56)
            .padding(.horizontal, 16)
            .transition(.opacity)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: closingAt == nil)
    }

    private func progress(at date: Date) -> Double {
        if reduceMotion { return closingAt == nil ? 1 : 0 }
        if let closingAt {
            return 1 - Gooey.ease(date.timeIntervalSince(closingAt) / closeDuration)
        }
        return Gooey.ease(date.timeIntervalSince(openedAt) / openDuration)
    }

    private func baseRadius(_ size: CGSize) -> CGFloat { min(size.width, size.height) / 2 * 0.62 }

    private func smallRadius(_ value: PersonalValue, size: CGSize, p: Double) -> CGFloat {
        // All the same size: a value doesn't get smaller when life gets in the way.
        baseRadius(size) * 0.27 * CGFloat(0.5 + 0.5 * p)
    }

    private func position(_ index: Int, center: CGPoint, size: CGSize, p: Double, t: Double) -> CGPoint {
        let n = max(values.count, 1)
        let slot: Double = 2 * Double.pi * Double(index) / Double(n)
        let sway: Double = sin(t * 0.2 + Double(index)) * 0.04
        let angle: Double = slot - Double.pi / 2 + sway
        let distance = baseRadius(size) * 1.25 * CGFloat(p)
        return CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle))
    }

    private func blobs(center: CGPoint, size: CGSize, p: Double, t: Double) -> [GooeyBlob] {
        let colors = palette.colors
        // The canvas is larger than the view by the bleed, so shift points into its space.
        let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let main = GooeyBlob(center: center, radius: baseRadius(size) * CGFloat(1 - 0.55 * p),
                             color: colors[1])
        let small = values.enumerated().map { index, value in
            let point = position(index, center: viewCenter, size: size, p: p, t: t)
            return GooeyBlob(center: CGPoint(x: point.x + bleed, y: point.y + bleed),
                             radius: smallRadius(value, size: size, p: p),
                             color: [colors[0], colors[2], colors[1]][index % 3])
        }
        return [main] + small
    }

    private func close() {
        guard closingAt == nil else { return }
        closingAt = .now
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : closeDuration))
            onClose()
        }
    }
}

// MARK: - A thought pinches off and drifts away

/// For parking a thought: a small orb pinches off the main one and drifts up
/// and away, to wait for the weekly review.
struct PinchOffOrb: View {
    let palette: OrbPalette
    /// The color of the small orb that floats away. Defaults to the palette's light.
    var dropColor: Color? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    private let bleed: CGFloat = 60

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let e = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = (min(size.width, size.height) - bleed * 2) / 2 * 0.7
                let p = reduceMotion ? 1 : Gooey.ease((e - 0.3) / 1.8)
                let angle = -Double.pi / 3
                let distance = r * 1.9 * CGFloat(p)
                let fade = reduceMotion ? 0 : max(0, 1 - max(0, e - 1.8) / 0.8)
                var blobs = [GooeyBlob(center: center, radius: r, color: palette.colors[1])]
                if fade > 0 {
                    blobs.append(GooeyBlob(center: CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle)),
                                           radius: r * 0.3 * CGFloat(fade), color: dropColor ?? palette.colors[2]))
                }
                Gooey.draw(blobs, in: ctx, base: palette.colors[0])
            }
            .padding(-bleed)
        }
        .accessibilityHidden(true)
    }
}

/// Parked thoughts as little orbs floating, waiting calmly to be looked at.
struct FloatingOrbs: View {
    let count: Int
    let palette: OrbPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ForEach(0..<min(count, 12), id: \.self) { i in
                    let seed = Double(i) * 1.7
                    let slot: Double = (Double(i) + 0.5) / Double(min(count, 12))
                    let x: CGFloat = proxy.size.width * CGFloat(slot)
                    let bob: CGFloat = CGFloat(sin(t * 0.5 + seed))
                    let y: CGFloat = proxy.size.height / 2 + bob * proxy.size.height * 0.22
                    MiniOrb(color: palette.colors[i % 3], seed: seed)
                        .frame(width: 30 + CGFloat(i % 3) * 6, height: 30 + CGFloat(i % 3) * 6)
                        .position(x: x, y: y)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) parked thought\(count == 1 ? "" : "s")")
    }
}

// MARK: - A constellation of check-ins

/// Each day you checked in this month is a soft point of light, joined to the
/// next by a faint line. Days without a check-in simply aren't drawn, so
/// there's never a gap to look at.
struct CheckInConstellation: View {
    let days: [Date]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let points = days.sorted().map { point(for: $0, in: size) }
                var line = Path()
                for (i, p) in points.enumerated() {
                    if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
                }
                ctx.stroke(line, with: .style(TintShapeStyle.tint.opacity(0.18)), lineWidth: 1)
                for (i, p) in points.enumerated() {
                    let twinkle = 0.65 + 0.35 * sin(t * 0.8 + Double(i) * 1.3)
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: 6))
                        layer.fill(Circle().path(in: Gooey.rect(p, 9)), with: .style(TintShapeStyle.tint.opacity(0.35 * twinkle)))
                    }
                    ctx.fill(Circle().path(in: Gooey.rect(p, 3)), with: .style(TintShapeStyle.tint.opacity(twinkle)))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.count) check-in day\(days.count == 1 ? "" : "s") this month")
    }

    /// Left to right through the month, with a steady, made-up height for each day
    /// so the same month always draws the same shape.
    private func point(for day: Date, in size: CGSize) -> CGPoint {
        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: day)
        let daysInMonth = calendar.range(of: .day, in: .month, for: day)?.count ?? 30
        let across: CGFloat = CGFloat(dayNumber - 1) / CGFloat(max(daysInMonth - 1, 1))
        let x: CGFloat = 16 + (size.width - 32) * across
        let wave: Double = sin(Double(dayNumber) * 2.39996) * 0.5 + 0.5 // the golden angle, for an even scatter
        let y: CGFloat = 20 + (size.height - 40) * CGFloat(wave)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Dispersing into light

/// The orb that ends a "calm your body" exercise: when `dispersed` turns true,
/// it loosens into small specks of light that drift outward and up and fade,
/// like the tension leaving. With Reduce Motion it simply fades.
struct DispersingOrb: View {
    var palette: OrbPalette
    var state: OrbState = .resting
    var dispersed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dispersedAt: Date?

    /// How long the specks take to fade completely.
    private let duration = 3.2
    private let count = 160
    /// Room around the frame for the specks to drift into.
    private let bleed: CGFloat = 140

    var body: some View {
        ZStack {
            if let dispersedAt, !reduceMotion {
                TimelineView(.animation) { timeline in
                    let e = timeline.date.timeIntervalSince(dispersedAt)
                    ZStack {
                        // The orb itself lets go in the first half second.
                        OrbView(palette: palette, speed: 0.5, state: .settling)
                            .scaleEffect(1 + 0.12 * min(e / 0.5, 1))
                            .opacity(max(0, 1 - e / 0.5))
                        Canvas { context, size in
                            drawSpecks(in: &context, size: size, elapsed: e)
                        }
                        .padding(-bleed)
                        .allowsHitTesting(false)
                    }
                }
            } else {
                OrbView(palette: palette, speed: 0.5, state: state)
                    .opacity(dispersed ? 0 : 1)
                    .animation(.easeOut(duration: 1.2), value: dispersed)
            }
        }
        .onChange(of: dispersed) { _, now in
            dispersedAt = now ? .now : nil
        }
        .accessibilityHidden(true)
    }

    /// A repeatable "random" number from 0 to 1, so each speck keeps its own path.
    private func noise(_ i: Int, _ salt: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    private func drawSpecks(in context: inout GraphicsContext, size: CGSize, elapsed e: Double) {
        guard e < duration else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = Double(min(size.width, size.height) - bleed * 2) / 2 * 0.78
        let colors = palette.colors
        let p = min(e / duration, 1)
        let travel = 1 - pow(1 - p, 3) // fast at first, then drifting

        for i in 0..<count {
            let angle = noise(i, 1) * 2 * .pi
            let start = sqrt(noise(i, 2)) * radius * 0.9
            let reach = radius * (0.5 + 1.3 * noise(i, 3))
            let distance = start + reach * travel
            let sway = sin(e * 1.6 + Double(i)) * 5 * p
            let rise = radius * 0.45 * p * (0.4 + noise(i, 4))
            let x = Double(center.x) + cos(angle) * distance + sway
            let y = Double(center.y) + sin(angle) * distance - rise

            // Each speck fades on its own schedule, so they don't vanish all at once.
            let life = 0.55 + 0.45 * noise(i, 5)
            let fade = max(0, 1 - p / life)
            guard fade > 0 else { continue }
            let opacity = pow(fade, 1.3) * (0.55 + 0.45 * noise(i, 6))
            let dot = 1.4 + 3.2 * noise(i, 7)
            let color = colors[i % colors.count]

            let glowRect = CGRect(x: x - dot * 2.2, y: y - dot * 2.2, width: dot * 4.4, height: dot * 4.4)
            context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(opacity * 0.25)))
            let coreRect = CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)
            context.fill(Path(ellipseIn: coreRect), with: .color(color.opacity(opacity)))
        }
    }
}
