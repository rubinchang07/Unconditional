import SwiftUI

/// Your guess at a shared root belief, glowing at the middle of the map like a sun.
/// Before you've written one, it's a dim little star waiting for a guess.
struct RootSun: View {
    let root: String

    private var hasRoot: Bool { !root.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFD59A).opacity(hasRoot ? 0.55 : 0.2), .clear],
                                         center: .center, startRadius: 0, endRadius: hasRoot ? 34 : 20))
                    .frame(width: hasRoot ? 68 : 40, height: hasRoot ? 68 : 40)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF1D6), Color(hex: 0xF6B86B)],
                                         center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 14))
                    .frame(width: hasRoot ? 22 : 10, height: hasRoot ? 22 : 10)
                    .opacity(hasRoot ? 1 : 0.6)
            }
            .frame(height: 30)
            if hasRoot {
                Text(MapLayout.shortRoot(root))
                    .font(.system(.caption2, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 120)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The small card that floats beside a loop you tapped.
struct LoopCard: View {
    let loop: Loop
    let color: Color
    let threads: Int
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(loop.name)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Text(loop.coreBelief.isEmpty ? "No core belief written yet." : loop.coreBelief)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
            HStack {
                Text("\(threads) thread\(threads == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("open", action: onOpen)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 30)
                    .background(.white.opacity(0.15), in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(12)
        .background(Color(hex: 0x1E2445).opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

/// A wordless, one-time demo: a ghost hand pulls a soft thread out of a loop and
/// drops it on a value, twice, then fades away.
struct ThreadDemo: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    private static let cycle = 2.4
    private static let cycles = 2.0

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? Self.cycle * 0.75 : timeline.date.timeIntervalSince(start)
            let t = elapsed.truncatingRemainder(dividingBy: Self.cycle)
            // Press (0.3s), pull across (1.2s), rest on the target, then fade.
            let pull = min(max((t - 0.3) / 1.2, 0), 1)
            let eased = pull * pull * (3 - 2 * pull)
            let tip = CGPoint(x: from.x + (to.x - from.x) * eased, y: from.y + (to.y - from.y) * eased)
            let fade = t > Self.cycle - 0.4 ? (Self.cycle - t) / 0.4 : min(t / 0.3, 1)
            ZStack {
                Canvas { ctx, _ in
                    var line = Path()
                    line.move(to: from)
                    line.addLine(to: tip)
                    ctx.stroke(line, with: .color(color.opacity(0.7 * fade)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 7]))
                    let r: CGFloat = 6
                    ctx.fill(Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(0.8 * fade)))
                }
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.85 * fade))
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .position(x: tip.x + 10, y: tip.y + 16)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(Self.cycle * Self.cycles))
            onDone()
        }
        .accessibilityHidden(true)
    }
}
