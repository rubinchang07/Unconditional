import SwiftUI

// The rain cycle in "i'm spiraling": a thought dropped into the water is let go;
// a thought lifted into the cloud is saved, and on Sunday the cloud rains it back.

/// A soft cloud: a few overlapping circles on a flat base.
struct Cloud: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path(roundedRect: CGRect(x: rect.minX + w * 0.08, y: rect.minY + h * 0.5, width: w * 0.84, height: h * 0.45),
                        cornerRadius: h * 0.22)
        let puffs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [(0.28, 0.55, 0.24), (0.5, 0.4, 0.32), (0.72, 0.55, 0.22)]
        for puff in puffs {
            let r = puff.r * w * 0.62
            path = path.union(Path(ellipseIn: CGRect(x: rect.minX + puff.x * w - r, y: rect.minY + puff.y * h - r,
                                                     width: r * 2, height: r * 2)))
        }
        return path
    }
}

/// Calm water along the bottom, with a slow wave on its surface.
/// Change `ripple` (with `rippleX` set) and a ring spreads where something landed.
struct ReleaseWater: View, Animatable {
    var color: Color
    var ripple: Int = 0
    var rippleX: CGFloat = 0.5
    /// 0 to 1: the water rises a little to meet a word that comes near.
    var swell: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippledAt: Date?

    var animatableData: Double {
        get { swell }
        set { swell = newValue }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && rippledAt == nil)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var water = Path()
                water.move(to: CGPoint(x: 0, y: size.height))
                // Two waves at different speeds, so the surface never looks mechanical.
                let lift = 18 * swell
                for x in stride(from: 0, through: size.width, by: 4) {
                    let y = 34 - lift + 6 * sin(x / 44 + t * 0.7) + 3 * sin(x / 19 - t * 1.1)
                    water.addLine(to: CGPoint(x: x, y: y))
                }
                water.addLine(to: CGPoint(x: size.width, y: size.height))
                water.closeSubpath()
                ctx.fill(water, with: .linearGradient(Gradient(colors: [color.opacity(0.35), color.opacity(0.6)]),
                                                      startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                ctx.stroke(water, with: .color(.white.opacity(0.5 + 0.3 * swell)), lineWidth: 1.5)
                // A softer second layer behind, drifting the other way.
                var back = Path()
                back.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0, through: size.width, by: 6) {
                    back.addLine(to: CGPoint(x: x, y: 26 - lift + 5 * sin(x / 60 - t * 0.5)))
                }
                back.addLine(to: CGPoint(x: size.width, y: size.height))
                back.closeSubpath()
                ctx.fill(back, with: .color(color.opacity(0.18)))

                if let rippledAt {
                    let e = timeline.date.timeIntervalSince(rippledAt)
                    if e < 1.6 {
                        for ring in 0..<2 {
                            let p = min(max((e - Double(ring) * 0.25) / 1.3, 0), 1)
                            let rx = 20 + 110 * p, ry = 6 + 18 * p
                            let cx = size.width * rippleX
                            ctx.stroke(Path(ellipseIn: CGRect(x: cx - rx, y: 42 - ry, width: rx * 2, height: ry * 2)),
                                       with: .color(.white.opacity(0.7 * (1 - p))), lineWidth: 1.5)
                        }
                    }
                }
            }
        }
        .onChange(of: ripple) { _, _ in rippledAt = .now }
        .accessibilityHidden(true)
    }
}

/// On Sunday: the cloud lets the saved thoughts fall back as a few seconds of soft rain.
struct SundayRain: View {
    let count: Int
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    private struct Drop { var x: CGFloat; var delay: Double; var speed: Double }
    @State private var drops: [Drop] = []

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let e = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let cloud = CGRect(x: size.width / 2 - 70, y: 4, width: 140, height: 56)
                for drop in drops {
                    let t = e - drop.delay
                    guard t > 0 else { continue }
                    let y = cloud.maxY + CGFloat(t * drop.speed)
                    guard y < size.height - 6 else { continue }
                    let x = cloud.minX + 16 + drop.x * (cloud.width - 32)
                    ctx.fill(Path(roundedRect: CGRect(x: x - 1.5, y: y, width: 3, height: 10), cornerRadius: 1.5),
                             with: .color(color.opacity(0.7)))
                }
                // A thin pool gathers underneath.
                let pool = min(1, e / 3)
                ctx.fill(Path(ellipseIn: CGRect(x: size.width / 2 - 80 * pool, y: size.height - 10, width: 160 * pool, height: 8)),
                         with: .color(color.opacity(0.35)))
            }
            .overlay(alignment: .top) {
                Cloud()
                    .fill(Color(light: 0xE6EBF2, dark: 0x3A4152))
                    .frame(width: 140, height: 56)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            // About four drops for each thought, falling over a few seconds, then it clears.
            drops = (0..<max(6, min(count * 4, 40))).map { _ in
                Drop(x: .random(in: 0...1), delay: .random(in: 0...2.6), speed: .random(in: 120...190))
            }
            start = .now
        }
        .accessibilityHidden(true)
    }
}

/// A handful of small bubbles rising and fading where a word sank into the water.
struct BubbleBurst: View {
    let color: Color
    @State private var start = Date.now
    @State private var finished = false

    private struct Bubble { var x: CGFloat; var size: CGFloat; var speed: Double; var delay: Double; var sway: Double }
    @State private var bubbles: [Bubble] = (0..<14).map { _ in
        Bubble(x: .random(in: -30...30), size: .random(in: 3...8), speed: .random(in: 40...90),
               delay: .random(in: 0...0.5), sway: .random(in: 0...6))
    }

    var body: some View {
        if !finished {
            TimelineView(.animation) { timeline in
                let e = timeline.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    for b in bubbles {
                        let t = e - b.delay
                        guard t > 0 else { continue }
                        let fade = max(0, 1 - t / 1.4)
                        let x = size.width / 2 + b.x + CGFloat(sin(t * 4 + b.sway) * 4)
                        let y = size.height * 0.75 - CGFloat(t * b.speed)
                        ctx.stroke(Path(ellipseIn: CGRect(x: x - b.size / 2, y: y - b.size / 2, width: b.size, height: b.size)),
                                   with: .color(color.opacity(0.8 * fade)), lineWidth: 1)
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(2))
                finished = true
            }
        }
    }
}

/// A soft sunset behind "i'm spiraling", in the colors of your theme: the sky
/// fades from pale above to warm near the horizon, and a low sun glows there,
/// sinking very slightly over time. Behind the water, it looks like it's setting into it.
struct SunsetBackground: View {
    @AppStorage(Theme.storageKey) private var theme: Theme = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = Self.colors(for: theme)
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                let sunY = size.height * 0.74 + CGFloat(4 * sin(t * 0.05))
                ZStack {
                    LinearGradient(stops: [.init(color: colors.top, location: 0),
                                           .init(color: colors.middle, location: 0.5),
                                           .init(color: colors.horizon, location: 0.82)],
                                   startPoint: .top, endPoint: .bottom)
                    // The glow around the sun, wide and faint.
                    RadialGradient(colors: [colors.sun.opacity(0.55), colors.sun.opacity(0)],
                                   center: UnitPoint(x: 0.5, y: sunY / max(size.height, 1)),
                                   startRadius: 10, endRadius: size.width * 0.8)
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.9), colors.sun],
                                             center: .center, startRadius: 0, endRadius: 70))
                        .frame(width: 130, height: 130)
                        .blur(radius: 2)
                        .position(x: size.width / 2, y: sunY)
                        .opacity(0.9)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    struct Colors { let top: Color; let middle: Color; let horizon: Color; let sun: Color }

    /// One sunset for each theme, with a deeper one in dark mode.
    static func colors(for theme: Theme) -> Colors {
        switch theme {
        case .white:
            Colors(top: Color(light: 0xFDF8F2, dark: 0x14131C), middle: Color(light: 0xFCE6D4, dark: 0x2B2233),
                   horizon: Color(light: 0xF6C7A9, dark: 0x4A2E36), sun: Color(light: 0xFFD49A, dark: 0xE9A07A))
        case .sage:
            Colors(top: Color(light: 0xF3F1E4, dark: 0x161A15), middle: Color(light: 0xF2E4C8, dark: 0x2A2A20),
                   horizon: Color(light: 0xE6C59E, dark: 0x45352A), sun: Color(light: 0xF6D38F, dark: 0xD9A266))
        case .dusk:
            Colors(top: Color(light: 0xE6DDF5, dark: 0x1C1828), middle: Color(light: 0xF2D6E0, dark: 0x34233A),
                   horizon: Color(light: 0xF5BDA8, dark: 0x5A3040), sun: Color(light: 0xFFC9A1, dark: 0xEE9A86))
        case .sky:
            Colors(top: Color(light: 0xDCEBF7, dark: 0x0F1A26), middle: Color(light: 0xF3E6DE, dark: 0x22304A),
                   horizon: Color(light: 0xF7C6AF, dark: 0x523A4A), sun: Color(light: 0xFFE0AE, dark: 0xF0B07E))
        }
    }
}
