import SwiftUI

/// Cognitive dissonance, drawn as sound: two waves, one for your head (how true the
/// kinder thought seems) and one for your heart (how light it actually feels).
///
/// Two notes that are close but not the same "beat": you hear a wobble that slows
/// and smooths out as they meet. Here the further apart head and heart are, the
/// more the waves clash and shimmer; as they come together they lock into one calm
/// wave. Nothing asks you to make them match. Knowing often comes before feeling.
struct HeadAndHeart: View {
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 "not really" to 1 "completely".
    @Binding var head: Double
    /// 0 heavy to 1 light.
    @Binding var heart: Double

    private var gap: Double { Self.gap(head: head, heart: heart) }

    var body: some View {
        let colors = orbPalette.colors
        VStack(spacing: 18) {
            DissonanceWaves(gap: gap, headColor: colors.first ?? .teal, heartColor: colors.last ?? .orange,
                            reduceMotion: reduceMotion)
                .frame(height: 96)
                .accessibilityHidden(true)

            if gap >= Self.noticeable {
                Text("Feelings often catch up later.")
                    .font(.system(.footnote, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            slider(symbol: "brain.head.profile", title: "In your head, how true is it?",
                   value: $head, low: "not really", high: "completely", color: colors.first ?? .teal)
            slider(symbol: "heart", title: "In your heart, how does it feel?",
                   value: $heart, low: "heavy", high: "light", color: colors.last ?? .orange)
        }
        .animation(.calm, value: gap >= Self.noticeable)
        // A soft buzz that grows with the clash, each time the gap shifts a step.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: max(0.25, gap)), trigger: Int(gap * 10))
    }

    private func slider(symbol: String, title: String, value: Binding<Double>,
                        low: String, high: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Slider(value: value, in: 0...1)
                .tint(color)
                .accessibilityLabel(title)
                .accessibilityValue(value.wrappedValue < 0.5 ? low : high)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// How far apart head and heart are, 0 (in tune) to 1.
    static func gap(head: Double, heart: Double) -> Double {
        min(abs(min(max(head, 0), 1) - min(max(heart, 0), 1)), 1)
    }

    /// From here on the gap shows, and the quiet line appears.
    static let noticeable = 0.25
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
