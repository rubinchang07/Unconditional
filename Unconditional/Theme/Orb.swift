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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 * 0.78
                let colors = palette.colors

                // 1. A wide, very soft glow behind everything.
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.22))
                    layer.fill(Self.blob(center: center, radius: radius * 1.02, time: t * 0.7, seed: 1),
                               with: .color(colors[0].opacity(0.55)))
                }

                // 2. The main body, with a gradient that slowly turns.
                let angle = t * 0.25
                let offset = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.06))
                    layer.fill(Self.blob(center: center, radius: radius * 0.9, time: t, seed: 2),
                               with: .linearGradient(Gradient(colors: [colors[0], colors[1]]),
                                                     startPoint: CGPoint(x: center.x + offset.x, y: center.y + offset.y),
                                                     endPoint: CGPoint(x: center.x - offset.x, y: center.y - offset.y)))
                }

                // 3. A drifting inner light.
                let drift = CGPoint(x: center.x + cos(t * 0.4) * radius * 0.2,
                                    y: center.y + sin(t * 0.5) * radius * 0.2)
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: radius * 0.14))
                    layer.fill(Self.blob(center: drift, radius: radius * 0.45, time: t * 1.3, seed: 3),
                               with: .color(colors[2].opacity(0.7)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// A closed wobbly circle. `seed` shifts the waves so each layer moves differently.
    static func blob(center: CGPoint, radius: CGFloat, time: Double, seed: Double) -> Path {
        var path = Path()
        let points = 120
        for i in 0...points {
            let theta = Double(i) / Double(points) * 2 * .pi
            let wobble = 1
                + 0.07 * sin(3 * theta + time * 0.9 + seed)
                + 0.045 * sin(5 * theta - time * 1.2 + seed * 2)
                + 0.03 * sin(2 * theta + time * 0.5 + seed * 3)
            let r = radius * CGFloat(wobble)
            let point = CGPoint(x: center.x + r * CGFloat(cos(theta)), y: center.y + r * CGFloat(sin(theta)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
