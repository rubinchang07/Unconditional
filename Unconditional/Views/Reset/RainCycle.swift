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
struct ReleaseWater: View {
    var color: Color
    var ripple: Int = 0
    var rippleX: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippledAt: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && rippledAt == nil)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var water = Path()
                water.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0, through: size.width, by: 6) {
                    water.addLine(to: CGPoint(x: x, y: 14 + 6 * sin(x / 44 + t * 0.7)))
                }
                water.addLine(to: CGPoint(x: size.width, y: size.height))
                water.closeSubpath()
                ctx.fill(water, with: .linearGradient(Gradient(colors: [color.opacity(0.35), color.opacity(0.6)]),
                                                      startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                ctx.stroke(water, with: .color(.white.opacity(0.5)), lineWidth: 1.5)

                if let rippledAt {
                    let e = timeline.date.timeIntervalSince(rippledAt)
                    if e < 1.6 {
                        for ring in 0..<2 {
                            let p = min(max((e - Double(ring) * 0.25) / 1.3, 0), 1)
                            let rx = 20 + 110 * p, ry = 6 + 18 * p
                            let cx = size.width * rippleX
                            ctx.stroke(Path(ellipseIn: CGRect(x: cx - rx, y: 22 - ry, width: rx * 2, height: ry * 2)),
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
