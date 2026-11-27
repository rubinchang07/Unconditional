import SwiftUI

/// The reverse of `DispersingOrb`: specks of light drift in from around the screen
/// and gather into the orb, which then appears where they met. Used at the end of
/// a scene, so whatever the orb became (water, words, leaves) comes back to it.
struct GatheringOrb<Orb: View>: View {
    var palette: OrbPalette
    @ViewBuilder var orb: () -> Orb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var gathered = false

    static var duration: Double { 1.8 }
    private let count = 120
    private let bleed: CGFloat = 160

    var body: some View {
        ZStack {
            orb()
                .scaleEffect(gathered || reduceMotion ? 1 : 0.6)
                .opacity(gathered || reduceMotion ? 1 : 0)
                .animation(.spring(duration: 0.9, bounce: 0.3), value: gathered)
            if !gathered && !reduceMotion {
                TimelineView(.animation) { timeline in
                    let e = timeline.date.timeIntervalSince(start)
                    Canvas { ctx, size in draw(in: &ctx, size: size, elapsed: e) }
                        .padding(-bleed)
                        .allowsHitTesting(false)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(Self.duration * 0.8))
            gathered = true
        }
    }

    private func noise(_ i: Int, _ salt: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, elapsed e: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = Double(min(size.width, size.height) - bleed * 2) / 2
        let colors = palette.colors
        for i in 0..<count {
            // Each speck sets off a little later than the last, and eases in.
            let delay = 0.35 * noise(i, 1)
            let p = min(max((e - delay) / (Self.duration * 0.8 - delay), 0), 1)
            let k = p * p * (3 - 2 * p)
            let angle = noise(i, 2) * 2 * .pi + (1 - k) * 0.8
            let distance = radius * (1.6 + 1.4 * noise(i, 3)) * (1 - k) + radius * 0.3 * noise(i, 4) * (1 - k)
            let x = Double(center.x) + cos(angle) * distance
            let y = Double(center.y) + sin(angle) * distance
            let opacity = min(p * 3, 1) * (0.5 + 0.5 * noise(i, 5))
            let dot = 1.4 + 3 * noise(i, 6)
            let color = colors[i % colors.count]
            ctx.fill(Path(ellipseIn: CGRect(x: x - dot * 2.2, y: y - dot * 2.2, width: dot * 4.4, height: dot * 4.4)),
                     with: .color(color.opacity(opacity * 0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)),
                     with: .color(color.opacity(opacity)))
        }
    }
}
