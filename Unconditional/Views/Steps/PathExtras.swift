import SwiftUI

// MARK: - The next print

/// The one step you mean to take next: a faint, dashed print just ahead of the
/// trail, breathing softly, as if waiting for a foot. When you take it, it fills in.
struct NextPrint: View {
    let isLeft: Bool
    let tilt: Double
    var reduceMotion: Bool

    var body: some View {
        let mark = Footprint(isLeft: isLeft)
            .stroke(Sand.print, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [3, 4]))
            .frame(width: 26, height: 56)
            .rotationEffect(.degrees(tilt))
        if reduceMotion {
            mark.opacity(0.6)
        } else {
            mark.phaseAnimator([false, true]) { content, glow in
                content.opacity(glow ? 0.85 : 0.4)
            } animation: { _ in .easeInOut(duration: 2.4) }
        }
    }
}

// MARK: - Shells

/// A small scallop shell: a fan with a gently scalloped edge and two little ears at the hinge.
struct ScallopShell: Shape {
    static let ridges = 6

    func path(in rect: CGRect) -> Path {
        let base = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height)
        let start = Double.pi * 1.1, end = Double.pi * 1.9
        let steps = Self.ridges * 4
        var path = Path()
        path.move(to: base)
        for i in 0...steps {
            let a = start + (end - start) * Double(i) / Double(steps)
            // Dips between the ridges make the scalloped edge.
            let bump = 1 - 0.08 * abs(sin(Double(i) * .pi / 4))
            path.addLine(to: CGPoint(x: base.x + cos(a) * radius * bump, y: base.y + sin(a) * radius * bump))
        }
        path.closeSubpath()
        path.addRoundedRect(in: CGRect(x: base.x - radius * 0.26, y: base.y - radius * 0.18,
                                       width: radius * 0.52, height: radius * 0.18),
                            cornerSize: CGSize(width: 1.5, height: 1.5))
        return path
    }
}

/// The ridges running out from the hinge of a `ScallopShell`.
struct ShellRidges: Shape {
    func path(in rect: CGRect) -> Path {
        let base = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height) * 0.9
        let start = Double.pi * 1.1, end = Double.pi * 1.9
        var path = Path()
        for i in 1..<ScallopShell.ridges {
            let a = start + (end - start) * Double(i) / Double(ScallopShell.ridges)
            path.move(to: CGPoint(x: base.x + cos(a) * radius * 0.2, y: base.y + sin(a) * radius * 0.2))
            path.addLine(to: CGPoint(x: base.x + cos(a) * radius, y: base.y + sin(a) * radius))
        }
        return path
    }
}

/// A shell lying in the sand.
struct ShellMark: View {
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight
    var body: some View {
        ZStack {
            ScallopShell().fill(Sand.rim)
            ScallopShell().stroke(Sand.ink.opacity(0.45), lineWidth: 0.8)
            ShellRidges().stroke(Sand.ink.opacity(0.35), lineWidth: 0.6)
        }
        .frame(width: 16, height: 12)
        .ownGlow(orbPalette.world.light, radius: 4)
        .accessibilityHidden(true)
    }
}

// MARK: - Seeing it from above

/// Where each print and tide sits when the whole path is seen from above:
/// a trail winding up the screen from the first step to the newest.
enum TrailLayout {
    static func points(count: Int, in size: CGSize, inset: CGFloat = 60) -> [CGPoint] {
        guard count > 0, size.width > 0, size.height > inset * 2 else { return [] }
        let height = size.height - inset * 2
        let width = size.width - 2 * 32
        // Longer paths wind a little more, so they don't become one long line.
        let turns = min(max(Double(count) / 8, 1.5), 4)
        return (0..<count).map { i in
            let t = count == 1 ? 0 : Double(i) / Double(count - 1)
            return CGPoint(x: size.width / 2 + CGFloat(sin(t * .pi * turns)) * width * 0.36,
                           y: size.height - inset - CGFloat(t) * height)
        }
    }

    /// How tall each print is drawn: smaller as the path grows, so it always fits.
    static func printHeight(count: Int, in size: CGSize, inset: CGFloat = 60) -> CGFloat {
        let spacing = (size.height - inset * 2) / CGFloat(max(count, 1))
        return min(max(spacing * 1.1, 9), 40)
    }
}

/// The whole path at once, from above: every print along a winding trail,
/// hard days as patches of wet sand, and the shells you left. It draws itself
/// from the first step upward. No count, no distance: just how far you've walked.
struct TrailOverview: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight
    private var water: Color { orbPalette.world.water }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let path: StepPath
    @State private var start = Date.now
    @State private var drawn = false

    private struct Item {
        var isTide: Bool
        var heaviness: Double
        var hasShell: Bool
    }

    /// How long the trail takes to draw itself.
    private static let reveal = 2.4

    var body: some View {
        let items = path.everything.map { Item(isTide: $0.isTide, heaviness: $0.heaviness, hasShell: !$0.shell.isEmpty) }
        ZStack {
            SandBackground(reduceMotion: true)
                .ignoresSafeArea()
            TimelineView(.animation(paused: drawn || reduceMotion)) { timeline in
                let progress = reduceMotion ? 1 : min(timeline.date.timeIntervalSince(start) / Self.reveal, 1)
                Canvas { ctx, size in draw(items, progress: progress, in: &ctx, size: size) }
            }
            .padding(.vertical, 40)

            VStack {
                VStack(spacing: 4) {
                    Text("toward")
                        .font(.caption)
                        .foregroundStyle(Sand.inkSoft)
                    Text(path.title)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(Sand.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 60)
                .padding(.top, 12)
                Spacer()
                Text("started \(path.createdAt.formatted(.dateTime.month(.wide).day().year()))")
                    .font(.caption)
                    .foregroundStyle(Sand.inkSoft)
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(Sand.inkSoft)
                .frame(width: 44, height: 44)
                .padding(.trailing, 8)
        }
        // Spreading your fingers goes back down to the sand.
        .gesture(MagnifyGesture().onEnded { if $0.magnification > 1.2 { dismiss() } })
        .task {
            try? await Task.sleep(for: .seconds(Self.reveal + 0.2))
            drawn = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your whole path toward \(path.title): \(path.walked.count) steps and \(path.tides.count) hard days")
    }

    private func draw(_ items: [Item], progress: Double, in ctx: inout GraphicsContext, size: CGSize) {
        let points = TrailLayout.points(count: items.count, in: size)
        guard !points.isEmpty else { return }
        let printH = TrailLayout.printHeight(count: items.count, in: size)
        let shown = Int((Double(items.count) * progress).rounded(.up))

        // The trail itself, a faint dashed line drawing upward as it goes.
        var trail = Path()
        trail.addLines(Array(points.prefix(max(shown, 1))))
        ctx.stroke(trail, with: .color(Sand.print.opacity(0.6)),
                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 5]))

        var printIndex = 0
        for (i, item) in items.enumerated() where i < shown {
            let p = points[i]
            if item.isTide {
                // Wet sand where the hard day was: wider and darker the harder it felt.
                let w = size.width * CGFloat(0.3 + 0.35 * item.heaviness)
                let h = printH * 1.8
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 10))
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)),
                               with: .color(water.opacity(0.25 + 0.3 * item.heaviness)))
                }
                continue
            }
            let isLeft = printIndex.isMultiple(of: 2)
            printIndex += 1
            let printW = printH * 26 / 56
            let x = p.x + (isLeft ? -printW * 0.7 : printW * 0.7)
            // Each print appears with a little fade as the trail reaches it.
            let age = Double(items.count) * progress - Double(i)
            ctx.drawLayer { layer in
                layer.opacity = min(max(age, 0), 1)
                layer.translateBy(x: x, y: p.y)
                layer.rotate(by: .degrees(cos(Double(i) * 0.7) * 14))
                let rect = CGRect(x: -printW / 2, y: -printH / 2, width: printW, height: printH)
                layer.fill(Footprint(isLeft: isLeft).path(in: rect), with: .color(Sand.print))
                layer.stroke(Footprint(isLeft: isLeft).path(in: rect), with: .color(Sand.rim), lineWidth: 0.8)
            }
            if item.hasShell {
                let s = max(printH * 0.4, 8)
                let rect = CGRect(x: x + (isLeft ? -printW - s : printW), y: p.y - s * 0.4, width: s * 1.3, height: s)
                ctx.fill(ScallopShell().path(in: rect), with: .color(Sand.rim))
                ctx.stroke(ScallopShell().path(in: rect), with: .color(Sand.ink.opacity(0.45)), lineWidth: 0.7)
                ctx.stroke(ShellRidges().path(in: rect), with: .color(Sand.ink.opacity(0.35)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - The orb as the sun on the horizon

/// When a path opens, the orb drops into its own small band above the title and
/// sinks halfway below a thin horizon line, where it stays as a low sun: the light
/// you walk toward. It has its own space, so it never sits behind any words.
struct HorizonSun: View {
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var set = false

    /// The band's height; the horizon line is at its bottom.
    static let height: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                OrbView(palette: orbPalette, speed: 0.4, state: .settling)
                    .frame(width: 84, height: 84)
                    // Comes in from above, then sets: half of it below the line.
                    .offset(y: set ? 42 : -30)
                    .opacity(set ? 0.9 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.height, alignment: .bottom)
            // Only what's above the horizon shows, fading softly into the sky at the top.
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35),
                                         .init(color: .black, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            Capsule()
                .fill(Sand.inkSoft.opacity(0.35))
                .frame(width: 150, height: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if reduceMotion { set = true; return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 1.8)) { set = true }
        }
    }
}
