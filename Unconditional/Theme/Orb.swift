import SwiftUI

/// Color sets for the orb.
enum OrbPalette: String, CaseIterable, Identifiable {
    case emberSage, midnight

    static let storageKey = "orbPalette"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .emberSage: "Ember & Sage"
        case .midnight: "Midnight"
        }
    }

    /// Three colors: outer glow, main body, inner light.
    /// Ember & Sage is a softened red-to-green, so it reads warm rather than alarming.
    var colors: [Color] {
        switch self {
        case .emberSage: [Color(hex: 0x8FC79A), Color(hex: 0xE9785E), Color(hex: 0xF6C38B)]
        case .midnight: [Color(hex: 0x4F7BE0), Color(hex: 0x141B3A), Color(hex: 0x9CC2FF)]
        }
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

/// What the app is doing, which the orb reflects. It never claims to know how
/// you feel. It only shows whether the app is resting, listening, breathing
/// with you, or settling after you've looked at a thought.
enum OrbState: Equatable {
    case resting, listening, breathing, settling

    /// How much the edge undulates, and how big the orb is.
    func shape(level: Double) -> (wobble: Double, scale: Double) {
        switch self {
        case .resting: (0.8, 1)
        case .listening: (1.4, 1 + 0.15 * level)
        case .breathing: (0.5, 1)
        case .settling: (0.3, 0.96)
        }
    }
}

/// A softly undulating orb, drawn every frame with Canvas.
///
/// How it works: a circle's radius is nudged by a few sine waves of different
/// frequencies that drift over time, so the edge "breathes" without ever repeating
/// exactly. Three blurred layers stacked on top give it depth.
/// With Reduce Motion turned on, the orb holds still.
struct OrbView: View {
    var palette: OrbPalette
    /// 1 = normal. Lower is calmer.
    var speed: Double = 1
    /// When true, touching the orb pulls its edge toward your finger, like
    /// pressing into something soft. The orb itself stays where it is.
    var interactive = false
    var state: OrbState = .resting
    /// Voice loudness, 0 to 1, used while listening.
    var level: Double = 0
    /// Change this number to make the orb ripple once, as if something soft landed in it.
    var ripple: Int = 0
    /// Called when you press and hold the orb.
    var onHold: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the finger is, in the orb's own frame. Kept after lifting so the
    /// edge can settle back from there.
    @State private var touch: CGPoint?
    @State private var touching = false
    /// When the finger lifted, so the pull can ease out with a little wobble.
    @State private var releasedAt: Date?

    /// For easing between states over about a second, instead of jumping.
    @State private var fromShape: (wobble: Double, scale: Double) = (0.8, 1)
    @State private var changedAt = Date.distantPast
    private static let transition = 1.2
    @State private var rippledAt = Date.distantPast
    @State private var holdTask: Task<Void, Never>?

    /// Extra room the canvas draws into beyond its frame. A Canvas clips to its
    /// bounds, so without this the blurred glow got cut off in a visible square.
    private let bleed: CGFloat = 90

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * speed
            let amount = pullAmount(at: timeline.date)
            let shape = currentShape(at: timeline.date, for: state)
            let wobble = shape.wobble
            let rippleScale = rippleAmount(at: timeline.date)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = (min(size.width, size.height) - bleed * 2) / 2 * 0.78 * shape.scale * rippleScale
                let colors = palette.colors
                // The finger, moved into the canvas's coordinates (which include the bleed).
                let pull = touch.map { Pull(point: CGPoint(x: $0.x + bleed, y: $0.y + bleed), amount: amount) }

                // 1. A wide, very soft glow behind everything.
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.22))
                    layer.fill(Self.blob(center: center, radius: radius * 1.02, time: t * 0.7, seed: 1, pull: pull, wobble: wobble),
                               with: .color(colors[0].opacity(0.55)))
                }

                // 2. The main body, with a gradient that slowly turns.
                let angle = t * 0.25
                let offset = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.06))
                    layer.fill(Self.blob(center: center, radius: radius * 0.9, time: t, seed: 2, pull: pull, wobble: wobble),
                               with: .linearGradient(Gradient(colors: [colors[0], colors[1]]),
                                                     startPoint: CGPoint(x: center.x + offset.x, y: center.y + offset.y),
                                                     endPoint: CGPoint(x: center.x - offset.x, y: center.y - offset.y)))
                }

                // 3. A drifting inner light.
                let drift = CGPoint(x: center.x + cos(t * 0.4) * radius * 0.2,
                                    y: center.y + sin(t * 0.5) * radius * 0.2)
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.14))
                    layer.fill(Self.blob(center: drift, radius: radius * 0.45, time: t * 1.3, seed: 3, pull: pull.map { Pull(point: $0.point, amount: $0.amount * 0.6) }, wobble: wobble),
                               with: .color(colors[2].opacity(0.7)))
                }
            }
            // The colors drift very slightly with the time of day: a touch cooler
            // in the morning, warmer at night. Subtle enough to notice only over time.
            .hueRotation(.degrees(Self.timeOfDayShift(timeline.date)))
            // Negative padding lets the canvas spill past the frame, so the glow
            // fades into the background with no edge, while layout stays the same size.
            .padding(-bleed)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    touch = value.location
                    releasedAt = nil
                    if !touching {
                        touching = true
                        startHoldTimer(from: value.startLocation)
                    }
                }
                .onEnded { _ in
                    touching = false
                    releasedAt = .now
                    holdTask?.cancel()
                },
            including: interactive ? .all : .none
        )
        .allowsHitTesting(interactive)
        .onAppear {
            // A settling orb arrives a little restless and calms down in front of you.
            if state == .settling {
                fromShape = OrbState.resting.shape(level: 0)
                changedAt = .now
            }
        }
        .onChange(of: ripple) { _, _ in rippledAt = .now }
        .onChange(of: state) { old, _ in
            fromShape = currentShape(at: .now, for: old)
            changedAt = .now
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: touching) { _, new in new }
        .accessibilityHidden(true)
    }

    /// How strongly the finger pulls, 0 to 1. While touching it's 1. After lifting
    /// it springs back: a decaying wobble over about a second, like jelly settling.
    private func pullAmount(at date: Date) -> Double {
        guard touch != nil else { return 0 }
        guard let releasedAt else { return 1 }
        let elapsed = date.timeIntervalSince(releasedAt)
        if reduceMotion || elapsed > 1.6 { return 0 }
        return exp(-elapsed * 3.5) * cos(elapsed * 9)
    }

    /// After half a second of holding fairly still, calls `onHold`.
    private func startHoldTimer(from start: CGPoint) {
        guard let onHold else { return }
        holdTask?.cancel()
        holdTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, touching, let touch,
                  hypot(touch.x - start.x, touch.y - start.y) < 30 else { return }
            onHold()
        }
    }

    /// A single soft ripple: a little swell that settles over about a second and a half.
    private func rippleAmount(at date: Date) -> CGFloat {
        let e = date.timeIntervalSince(rippledAt)
        guard e >= 0, e < 1.6, !reduceMotion else { return 1 }
        return 1 + CGFloat(0.08 * exp(-e * 3) * sin(e * 11))
    }

    /// Degrees of hue shift for the hour: cooler mornings, warmer evenings.
    static func timeOfDayShift(_ date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return 6
        case 11..<17: return 0
        case 17..<21: return -7
        default: return -12
        }
    }

    /// The shape right now: eased from where the last state left off toward this one.
    private func currentShape(at date: Date, for state: OrbState) -> (wobble: Double, scale: Double) {
        let target = state.shape(level: level)
        let progress = reduceMotion ? 1 : min(1, max(0, date.timeIntervalSince(changedAt) / Self.transition))
        let eased = progress * progress * (3 - 2 * progress) // smoothstep
        return (fromShape.wobble + (target.wobble - fromShape.wobble) * eased,
                fromShape.scale + (target.scale - fromShape.scale) * eased)
    }

    /// A finger pulling on the edge.
    struct Pull {
        var point: CGPoint
        var amount: Double
    }

    /// A closed wobbly circle. `seed` shifts the waves so each layer moves differently.
    static func blob(center: CGPoint, radius: CGFloat, time: Double, seed: Double, pull: Pull? = nil, wobble amplitude: Double = 1) -> Path {
        var path = Path()
        let points = 120

        // The finger's direction and distance from the middle. The edge bulges
        // toward it in a soft bell shape, more when the finger is further out,
        // capped so the orb stretches but never tears.
        var pullAngle = 0.0
        var pullSize = 0.0
        if let pull, pull.amount != 0 {
            let dx = Double(pull.point.x - center.x), dy = Double(pull.point.y - center.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            pullAngle = atan2(dy, dx)
            let reach = min(max(distance / Double(radius), 0.35), 1.6)
            pullSize = 0.22 * reach * pull.amount
        }

        for i in 0...points {
            let theta = Double(i) / Double(points) * 2 * .pi
            let wobble = 1 + amplitude * (
                0.07 * sin(3 * theta + time * 0.9 + seed)
                + 0.045 * sin(5 * theta - time * 1.2 + seed * 2)
                + 0.03 * sin(2 * theta + time * 0.5 + seed * 3))
            var delta = theta - pullAngle
            delta = atan2(sin(delta), cos(delta)) // wrap to -pi...pi
            let bulge = pullSize * exp(-(delta * delta) / (2 * 0.45 * 0.45))
            let r = radius * CGFloat(wobble + bulge)
            let point = CGPoint(x: center.x + r * CGFloat(cos(theta)), y: center.y + r * CGFloat(sin(theta)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
