import SwiftUI

/// The night sky behind your map: a deep, soft gradient, a faint warm glow at the
/// middle where your values sit, and slow-twinkling stars that drift a little as
/// you turn the map, so it feels like looking into space rather than at a chart.
struct SpaceBackdrop: View {
    var spin: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OrbMotion.storageKey) private var motion: OrbMotion = .always

    /// Stars in fixed places (the same every time), as fractions of the size.
    private static let stars: [(x: Double, y: Double, size: Double, phase: Double)] = {
        var seed: UInt64 = 7
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<90).map { _ in (next(), next(), 0.5 + next() * 1.3, next() * 2 * .pi) }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion || motion != .always)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let reach = max(size.width, size.height) * 0.75
                ctx.fill(Path(rect), with: .radialGradient(
                    Gradient(colors: [Color(hex: 0x1E2445), Color(hex: 0x111428), Color(hex: 0x080A16)]),
                    center: center, startRadius: 0, endRadius: reach))

                // A faint warm core, like a distant sun.
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - 70, y: center.y - 70, width: 140, height: 140)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xF6C98B).opacity(0.16), .clear]),
                                               center: center, startRadius: 0, endRadius: 70))

                // Stars turn a little with the map (much less than the map itself), for depth.
                let turn = spin * 0.2
                for star in Self.stars {
                    let x = (star.x - 0.5) * size.width * 1.4, y = (star.y - 0.5) * size.height * 1.4
                    let p = CGPoint(x: center.x + x * cos(turn) - y * sin(turn),
                                    y: center.y + x * sin(turn) + y * cos(turn))
                    guard rect.insetBy(dx: -2, dy: -2).contains(p) else { continue }
                    let twinkle = 0.55 + 0.45 * sin(t * 0.8 + star.phase)
                    let r = star.size / 2
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.25 + 0.5 * twinkle)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A wordless "you can turn this": a small hand sliding along a curved track,
/// shown until the first time you turn the map.
struct TurnCue: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swing = false

    var body: some View {
        ZStack {
            // A gentle arc with an arrowhead at each end.
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: -size.width * 0.9)
                let radius = size.width * 1.1
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .degrees(66), endAngle: .degrees(114), clockwise: false)
                ctx.stroke(arc, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                for (angle, direction) in [(66.0, -1.0), (114.0, 1.0)] {
                    let a = angle * .pi / 180
                    let tip = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
                    var head = Path()
                    head.move(to: CGPoint(x: tip.x - 6 * direction, y: tip.y - 4))
                    head.addLine(to: tip)
                    head.addLine(to: CGPoint(x: tip.x - 6 * direction, y: tip.y + 4))
                    ctx.stroke(head, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
            .frame(width: 120, height: 30)

            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.7))
                .offset(x: reduceMotion ? 0 : (swing ? 30 : -30), y: 14)
        }
        .frame(width: 120, height: 44)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { swing = true }
        }
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}

/// Small round icon buttons that sit on the night sky.
struct SpaceIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 34, height: 34)
            .background(.white.opacity(configuration.isPressed ? 0.2 : 0.1), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.8))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }
}
