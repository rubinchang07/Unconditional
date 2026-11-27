import SwiftUI

/// Cognitive dissonance, drawn as sound, shown once at the end of a reframe: one wave
/// for your heart (how heavy it felt, from the first screen) and one for your head (how
/// heavy it looks stepped back, from the second), on the same heavy-to-light scale, so
/// both heavy or both light is in tune. You only see them together here, so
/// neither answer was nudged by the picture.
///
/// Two notes that are close but not the same "beat": you hear a wobble that slows
/// and smooths out as they meet. Here the further apart head and heart are, the
/// more the waves clash and shimmer; as they come together they lock into one calm
/// wave. Nothing asks you to make them match. Knowing often comes before feeling.
struct HeadAndHeart: View {
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How heavy it looks stepped back, 0 heavy to 1 light (same scale as the heart).
    let head: Double
    /// How it feels, 0 heavy to 1 light.
    let heart: Double
    let onDone: () -> Void
    /// The waves start in tune and drift to the real gap, so you watch them meet or part.
    @State private var shown = 0.0

    private var gap: Double { Self.gap(head: head, heart: heart) }

    var body: some View {
        let colors = orbPalette.colors
        let headColor = colors.first ?? .teal, heartColor = colors.last ?? .orange
        VStack(spacing: 26) {
            Spacer()
            DissonanceWaves(gap: shown, headColor: headColor, heartColor: heartColor, reduceMotion: reduceMotion)
                .frame(height: 110)
                .accessibilityHidden(true)
            HStack(spacing: 22) {
                Label("head", systemImage: "circle.fill").foregroundStyle(headColor)
                Label("heart", systemImage: "circle.fill").foregroundStyle(heartColor)
            }
            .font(.caption)
            .labelStyle(DotLabel())
            Text(Self.message(gap: gap))
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
            Spacer()
            Button("Continue", action: onDone)
                .buttonStyle(.paper)
                .padding(.bottom, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackground())
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeInOut(duration: 2.4)) { shown = gap }
        }
        // A soft buzz that grows with the clash, as the waves part.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: max(0.25, gap)), trigger: shown > 0.01)
        .accessibilityElement(children: .combine)
    }

    /// How far apart head and heart are, 0 (in tune) to 1.
    static func gap(head: Double, heart: Double) -> Double {
        min(abs(min(max(head, 0), 1) - min(max(heart, 0), 1)), 1)
    }

    /// From here on the gap counts as noticeable.
    static let noticeable = 0.25

    /// Never says they should match. Understanding and feeling move at their own pace.
    static func message(gap: Double) -> String {
        gap >= noticeable
            ? "Understanding and feeling often move at different times. Both are real."
            : "Your head and heart agree right now."
    }
}

/// A small colored dot beside a word.
private struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 8))
            configuration.title.foregroundStyle(.secondary)
        }
    }
}

/// Two waves and what they make together. In tune: one smooth wave. Apart: the
/// second wave runs at a different pitch, so the sum swells and pinches ("beats"),
/// with a little shimmer the wider the gap.
struct DissonanceWaves: View {
    let gap: Double
    let headColor: Color
    let heartColor: Color
    var reduceMotion = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let mid = size.height / 2
                let amp = size.height * 0.2
                let base = 2 * Double.pi / 90          // one wavelength every 90 points
                let other = base * (1 + 0.45 * gap)    // the heart's pitch drifts with the gap
                func wave(_ k: Double, _ speed: Double, _ x: Double) -> Double { sin(k * x - t * speed) }

                var head = Path(), heart = Path(), sum = Path()
                for x in stride(from: 0.0, through: Double(size.width), by: 2) {
                    let a = wave(base, 2.2, x)
                    let b = wave(other, 2.2 + 3 * gap, x)
                    // A faint tremble on the combined line when they clash.
                    let shimmer = gap * 0.18 * sin(x * 0.9 + t * 17)
                    let pa = CGPoint(x: x, y: mid - amp * a)
                    let pb = CGPoint(x: x, y: mid - amp * b)
                    let ps = CGPoint(x: x, y: mid - amp * 0.95 * (a + b + shimmer))
                    if x == 0 { head.move(to: pa); heart.move(to: pb); sum.move(to: ps) }
                    else { head.addLine(to: pa); heart.addLine(to: pb); sum.addLine(to: ps) }
                }
                ctx.stroke(head, with: .color(headColor.opacity(0.45)), lineWidth: 1.5)
                ctx.stroke(heart, with: .color(heartColor.opacity(0.45)), lineWidth: 1.5)
                // The sound they make together, softly glowing.
                let blend = headColor.mix(with: heartColor, by: 0.5)
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 4))
                    layer.stroke(sum, with: .color(blend.opacity(0.45)), lineWidth: 5)
                }
                ctx.stroke(sum, with: .color(blend), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
