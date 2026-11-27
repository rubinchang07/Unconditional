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

/// A sunset behind the water-and-cloud screen of "i'm spiraling", in your theme's colors,
/// drawn like a simple painting: bands of sky, a crisp low sun with a few stripes cut
/// through its lower half, faint rings of light, thin wisps of cloud drifting across,
/// and two soft hills on the horizon. It sinks very slowly, as if setting into the water.
struct SunsetBackground: View {
    @AppStorage(Theme.storageKey) private var theme: Theme = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Self.colors(for: theme, dark: scheme == .dark)
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(Self.start)
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let horizon = h * 0.72
                // 1. The sky, in four bands that blend into each other.
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(stops: [.init(color: c.top, location: 0),
                                                                .init(color: c.upper, location: 0.35),
                                                                .init(color: c.lower, location: 0.6),
                                                                .init(color: c.horizon, location: 0.74)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

                // 2. The sun, sinking a few points over a minute or two.
                let r = min(w * 0.24, 110)
                let sun = CGPoint(x: w * 0.5, y: horizon - r * 0.35 + CGFloat(min(t, 120) / 120) * r * 0.25)
                // Faint rings of light around it.
                for ring in 1...3 {
                    let rr = r * (1 + 0.35 * CGFloat(ring))
                    ctx.stroke(Path(ellipseIn: CGRect(x: sun.x - rr, y: sun.y - rr, width: rr * 2, height: rr * 2)),
                               with: .color(c.sunTop.opacity(0.18 / Double(ring))), lineWidth: 1.2)
                }
                ctx.fill(Path(ellipseIn: CGRect(x: sun.x - r * 2.2, y: sun.y - r * 2.2, width: r * 4.4, height: r * 4.4)),
                         with: .radialGradient(Gradient(colors: [c.sunTop.opacity(0.35), c.sunTop.opacity(0)]),
                                               center: sun, startRadius: r * 0.8, endRadius: r * 2.2))
                // The disc, with stripes cut through its lower half, thicker toward the bottom.
                ctx.drawLayer { layer in
                    layer.fill(Path(ellipseIn: CGRect(x: sun.x - r, y: sun.y - r, width: r * 2, height: r * 2)),
                               with: .linearGradient(Gradient(colors: [c.sunTop, c.sunBottom]),
                                                     startPoint: CGPoint(x: 0, y: sun.y - r), endPoint: CGPoint(x: 0, y: sun.y + r)))
                    layer.blendMode = .destinationOut
                    for i in 0..<4 {
                        let y = sun.y + r * (0.18 + 0.2 * CGFloat(i))
                        let thickness = 2 + CGFloat(i) * 2.2
                        layer.fill(Path(CGRect(x: sun.x - r - 2, y: y, width: r * 2 + 4, height: thickness)), with: .color(.black))
                    }
                }

                // 3. Thin wisps of cloud, drifting slowly across the sun.
                for (i, wisp) in c.wisps.enumerated() {
                    let speed = 6 + Double(i) * 3
                    let length = w * (0.45 + 0.12 * CGFloat(i))
                    let x = CGFloat((t * speed + Double(i) * 170).truncatingRemainder(dividingBy: Double(w + length))) - length
                    let y = horizon - r * (1.4 - 0.45 * CGFloat(i))
                    ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: length, height: 7 - CGFloat(i)), cornerRadius: 4),
                             with: .color(wisp))
                }

                // 4. Two soft hills on the horizon, the nearer one darker.
                func hill(_ base: CGFloat, _ height: CGFloat, _ wave: CGFloat, _ phase: CGFloat, _ color: Color) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: h))
                    for x in stride(from: CGFloat(0), through: w, by: 4) {
                        let y = base - height * (0.5 + 0.5 * sin(x / wave + phase))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(color))
                }
                hill(horizon + 4, 22, 70, 1.2, c.hillFar)
                hill(horizon + 18, 16, 46, 3.1, c.hillNear)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Where the slow sinking is measured from: the moment the app first draws a sunset.
    private static let start = Date.now

    struct Colors {
        let top, upper, lower, horizon, sunTop, sunBottom, hillFar, hillNear: Color
        let wisps: [Color]
    }

    private static func c(_ hex: UInt32) -> Color { Color(hex: hex) }

    /// One sunset for each theme, and a deeper, glowing one for dark mode.
    static func colors(for theme: Theme, dark: Bool) -> Colors {
        switch (theme, dark) {
        case (.white, false):
            Colors(top: c(0xFFF6EC), upper: c(0xFFE2C6), lower: c(0xFFC09A), horizon: c(0xF59A7E),
                   sunTop: c(0xFFE7A3), sunBottom: c(0xFF9F6E), hillFar: c(0xD98C86).opacity(0.75), hillNear: c(0xB97482).opacity(0.85),
                   wisps: [c(0xFFFFFF).opacity(0.55), c(0xFFE4D6).opacity(0.5), c(0xFFD2C2).opacity(0.45)])
        case (.white, true):
            Colors(top: c(0x0F1020), upper: c(0x2A1E3A), lower: c(0x5A2E48), horizon: c(0x9A4A4E),
                   sunTop: c(0xFFC98A), sunBottom: c(0xF0766A), hillFar: c(0x3A2238).opacity(0.9), hillNear: c(0x24172A),
                   wisps: [c(0xF6A6A0).opacity(0.35), c(0xD98AA0).opacity(0.3), c(0xB07AA8).opacity(0.25)])
        case (.sage, false):
            Colors(top: c(0xF2F2E4), upper: c(0xF3E4C0), lower: c(0xF0C994), horizon: c(0xE3A577),
                   sunTop: c(0xFFE6A0), sunBottom: c(0xF4A566), hillFar: c(0xA9B48A).opacity(0.8), hillNear: c(0x7E9470).opacity(0.9),
                   wisps: [c(0xFFFFFF).opacity(0.5), c(0xFFF0D8).opacity(0.5), c(0xF8DDBF).opacity(0.45)])
        case (.sage, true):
            Colors(top: c(0x10140F), upper: c(0x2A2A1C), lower: c(0x5A4626), horizon: c(0x94643A),
                   sunTop: c(0xFFD48A), sunBottom: c(0xE88A52), hillFar: c(0x2E3424).opacity(0.95), hillNear: c(0x1C2218),
                   wisps: [c(0xF2C48A).opacity(0.3), c(0xD9A872).opacity(0.28), c(0xB88E62).opacity(0.22)])
        case (.dusk, false):
            Colors(top: c(0xE3D6F7), upper: c(0xF0CFE6), lower: c(0xF8B9C0), horizon: c(0xF59A98),
                   sunTop: c(0xFFE0B0), sunBottom: c(0xFF8F8A), hillFar: c(0xB592C4).opacity(0.75), hillNear: c(0x8C6FA8).opacity(0.85),
                   wisps: [c(0xFFFFFF).opacity(0.5), c(0xFBE2F0).opacity(0.5), c(0xF6CFE2).opacity(0.45)])
        case (.dusk, true):
            Colors(top: c(0x120E22), upper: c(0x2E1E44), lower: c(0x5E2C58), horizon: c(0xA04A66),
                   sunTop: c(0xFFC6A0), sunBottom: c(0xF06E86), hillFar: c(0x34204A).opacity(0.9), hillNear: c(0x21152F),
                   wisps: [c(0xF0A0C0).opacity(0.32), c(0xC88AC0).opacity(0.28), c(0x9E7AC0).opacity(0.24)])
        case (.sky, false):
            Colors(top: c(0xCFE5F7), upper: c(0xE8E6EE), lower: c(0xFAD2BE), horizon: c(0xF7A88E),
                   sunTop: c(0xFFEAB2), sunBottom: c(0xFFA678), hillFar: c(0x8FA9C8).opacity(0.75), hillNear: c(0x6A86A8).opacity(0.85),
                   wisps: [c(0xFFFFFF).opacity(0.6), c(0xFFEDE4).opacity(0.5), c(0xFFDCCF).opacity(0.45)])
        case (.sky, true):
            Colors(top: c(0x08121E), upper: c(0x1A2A48), lower: c(0x48406A), horizon: c(0x9A5A6A),
                   sunTop: c(0xFFD7A0), sunBottom: c(0xF08A6E), hillFar: c(0x1E2C46).opacity(0.95), hillNear: c(0x121C30),
                   wisps: [c(0xF2B0A0).opacity(0.3), c(0xC09AB8).opacity(0.26), c(0x8A9AC8).opacity(0.22)])
        }
    }
}
