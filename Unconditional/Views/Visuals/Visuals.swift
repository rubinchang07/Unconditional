import SwiftUI

// Small visual pieces that show things as shapes instead of sentences.

// MARK: - Before and after orbs

/// Two soft orbs, sized by distress. You see it shrink (or not) without reading numbers.
struct DistressOrbs: View {
    let before: Double
    let after: Double
    var maxSize: CGFloat = 120

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            orb(before, label: "before", tone: .secondary.opacity(0.55))
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            orb(after, label: "after", tone: .tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Distress \(Int(before.rounded())) before, \(Int(after.rounded())) after, out of 10")
    }

    private func size(_ value: Double) -> CGFloat {
        // Never vanishes completely: some feeling is always allowed.
        maxSize * (0.25 + 0.75 * CGFloat(min(max(value, 0), 10)) / 10)
    }

    private func orb(_ value: Double, label: String, tone: some ShapeStyle) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(tone).blur(radius: 10).opacity(0.5)
                Circle().fill(tone)
            }
            .frame(width: size(value), height: size(value))
            .frame(width: maxSize, height: maxSize)
            .animation(.spring(duration: 0.6), value: value)
            Text(label).font(.caption).foregroundStyle(.secondary).softCase()
        }
    }
}

/// A soft bar that fills to show how much you believed the thought, before and after.
struct BeliefBars: View {
    let before: Double
    let after: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("believed the thought").font(.caption).foregroundStyle(.secondary).softCase()
            bar(before, tone: .secondary.opacity(0.45))
            bar(after, tone: .tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Believed the thought \(Int(before))% before, \(Int(after))% after")
    }

    private func bar(_ percent: Double, tone: some ShapeStyle) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.tint.opacity(0.1))
                Capsule().fill(tone).frame(width: proxy.size.width * CGFloat(percent / 100))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Clock dial

/// A 24-hour ring. Each hour glows more when you checked in then more often.
/// Midnight sits at the top, noon at the bottom.
struct ClockDial: View {
    /// Number of check-ins in each hour, 0 to 23.
    let hours: [Int]

    var body: some View {
        let maxCount = max(hours.max() ?? 0, 1)
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 22
                for hour in 0..<24 {
                    let start = Angle.degrees(Double(hour) * 15 - 90 + 1.5)
                    let end = Angle.degrees(Double(hour + 1) * 15 - 90 - 1.5)
                    var arc = Path()
                    arc.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                    let share = Double(hours[hour]) / Double(maxCount)
                    ctx.stroke(arc, with: .color(.secondary.opacity(0.12)), style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                    if share > 0 {
                        ctx.stroke(arc, with: .style(.tint.opacity(0.25 + 0.75 * share)),
                                   style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                    }
                }
            }
            // Four quiet markers instead of twenty-four numbers.
            GeometryReader { proxy in
                let c = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let r = min(proxy.size.width, proxy.size.height) / 2 - 4
                ForEach([(0, "moon"), (6, "sunrise"), (12, "sun.max"), (18, "sunset")], id: \.0) { hour, symbol in
                    let angle = Double(hour) * 15 - 90
                    Image(systemName: symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: c.x + r * cos(angle * .pi / 180), y: c.y + r * sin(angle * .pi / 180))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Check-ins by hour of day")
    }
}

// MARK: - Bubbles

/// Packs circles of different sizes close together around the middle, biggest first.
struct BubbleCluster: Layout {
    var spacing: CGFloat = 6

    private func positions(_ diameters: [CGFloat]) -> [CGPoint] {
        var placed: [(point: CGPoint, d: CGFloat)] = []
        for d in diameters {
            guard !placed.isEmpty else { placed.append((.zero, d)); continue }
            var t: CGFloat = 0
            while true {
                // Walk outward on a spiral until this bubble fits.
                let r = 4 * t
                let p = CGPoint(x: r * cos(t), y: r * sin(t) * 0.75)
                let fits = placed.allSatisfy { other in
                    hypot(other.point.x - p.x, other.point.y - p.y) >= (other.d + d) / 2 + spacing
                }
                if fits { placed.append((p, d)); break }
                t += 0.1
            }
        }
        return placed.map(\.point)
    }

    private func frame(_ subviews: Subviews) -> (points: [CGPoint], sizes: [CGSize], box: CGRect) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let points = positions(sizes.map { max($0.width, $0.height) })
        var box = CGRect.null
        for (p, s) in zip(points, sizes) {
            box = box.union(CGRect(x: p.x - s.width / 2, y: p.y - s.height / 2, width: s.width, height: s.height))
        }
        return (points, sizes, box.isNull ? .zero : box)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let box = frame(subviews).box
        return CGSize(width: proposal.width ?? box.width, height: box.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (points, sizes, box) = frame(subviews)
        let shift = CGPoint(x: bounds.midX - box.midX, y: bounds.midY - box.midY)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: points[index].x + shift.x, y: points[index].y + shift.y),
                          anchor: .center, proposal: ProposedViewSize(sizes[index]))
        }
    }
}

/// One loop as a bubble: bigger when it came up more. A small arrow shows
/// whether it came up more or less than the weeks before.
/// A loop drawn as what it is: a ring you go around.
///
/// - Each time it came up adds one more thin turn, like a coil (up to seven),
///   so "often" looks like "around and around", never like a number.
/// - When it came up less than the period before, the ring opens: a soft gap,
///   as if the loop is loosening. Coming up more never looks alarming, just more turns.
/// - It turns slowly, with the orb's soft wobble, and stands still with Reduce Motion.
struct LoopRing: View {
    let name: String
    let count: Int
    let previous: Int
    let maxCount: Int
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var diameter: CGFloat {
        let share = maxCount == 0 ? 0 : sqrt(Double(count) / Double(maxCount))
        return 92 + 64 * CGFloat(share)
    }

    /// How many turns to draw.
    var turns: Int { min(max(count, 1), 7) }

    /// The gap in radians: none if it came up as much or more, up to about a third of the ring.
    var gap: Double {
        guard previous > 0, count < previous else { return 0 }
        let eased = Double(previous - count) / Double(previous)
        return 0.35 + 1.75 * eased
    }

    var body: some View {
        ZStack {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                Canvas { context, size in
                    draw(in: &context, size: size, time: t)
                }
            }
            .padding(-8) // room for the soft glow
            Text(name)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.primary)
                .padding(diameter * 0.2)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = Double(diameter) / 2 - 4
        let spin = time * 0.12 + Double(name.count)
        let seed = Double(name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 100)

        for turn in 0..<turns {
            let share = turns == 1 ? 1.0 : Double(turn) / Double(turns - 1)
            let radius = outer * (0.8 + 0.2 * share)
            let start = spin + gap / 2 + Double(turn) * 0.4
            let sweep = 2 * Double.pi - gap
            let closed = gap == 0

            var path = Path()
            let steps = 96
            for step in 0...steps {
                let angle = start + sweep * Double(step) / Double(steps)
                let wobble1: Double = sin(angle * 3 + time * 0.6 + seed + Double(turn)) * 1.6
                let wobble2: Double = sin(angle * 5 - time * 0.4 + Double(turn) * 1.3) * 0.9
                let r = radius + wobble1 + wobble2
                let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            if closed { path.closeSubpath() }

            let strength = 0.35 + 0.65 * Double(turn + 1) / Double(turns)
            let style = StrokeStyle(lineWidth: turn == turns - 1 ? 3 : 1.6, lineCap: .round, lineJoin: .round)
            // A faint glow under each turn, then the line itself.
            var glow = context
            glow.addFilter(.blur(radius: 4))
            glow.stroke(path, with: .color(color.opacity(0.35 * strength)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            context.stroke(path, with: .color(color.opacity(strength)), style: style)
        }
    }

    private var accessibilityText: String {
        let times = "came up \(count) time\(count == 1 ? "" : "s")"
        if previous == 0 || count == previous { return "\(name), \(times)" }
        return count < previous
            ? "\(name), \(times), less than before (\(previous)). The ring is opening."
            : "\(name), \(times), more than before (\(previous))."
    }
}

/// A small, still loop ring for tight spaces like the map: two soft turns and a glow.
struct MiniRing: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 6)
                .blur(radius: 4)
            Circle()
                .inset(by: 5)
                .stroke(color.opacity(0.5), lineWidth: 1.5)
            Circle()
                .inset(by: 1.5)
                .stroke(color, lineWidth: 3)
        }
        .padding(2)
    }
}

// MARK: - Calendar of dots

/// One soft dot per day, colored by the loop you wrote about. Empty days are
/// faint outlines, not gaps to feel bad about.
struct CalendarDots: View {
    /// Colors for each day that has entries, keyed by start of day.
    let days: [Date: [Color]]
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.system(.headline, design: .serif))
                    .softCase()
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
                    .accessibilityLabel("Next month")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2).foregroundStyle(.tertiary)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 30) }
                ForEach(daysInMonth, id: \.self) { day in
                    dot(for: day)
                }
            }
        }
        .animation(.calm, value: month)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: month)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    @ViewBuilder
    private func dot(for day: Date) -> some View {
        let colors = days[calendar.startOfDay(for: day)] ?? []
        let isToday = calendar.isDateInToday(day)
        ZStack {
            if colors.isEmpty {
                Circle().stroke(.secondary.opacity(0.2), lineWidth: 1)
            } else if colors.count == 1 {
                Circle().fill(colors[0].gradient)
            } else {
                // Several loops that day: the dot is split into soft slices.
                Circle().fill(AngularGradient(colors: colors + [colors[0]], center: .center))
            }
            if isToday {
                Circle().stroke(.primary.opacity(0.6), lineWidth: 1.5).padding(-3)
            }
        }
        .frame(width: 22, height: 22)
        .frame(height: 30)
        .accessibilityLabel(Text(day, format: .dateTime.month().day()) + Text(colors.isEmpty ? ", no check-in" : ", \(colors.count) loop\(colors.count == 1 ? "" : "s")"))
    }

    private func shift(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) { month = next }
    }
}

// MARK: - Value ring

/// A ring that fills to show how much you've lived a value lately.
struct ValueRing: View {
    let amount: Double // 0 to 10
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle().stroke(.tint.opacity(0.15), lineWidth: max(3, size * 0.14))
            Circle()
                .trim(from: 0, to: CGFloat(min(max(amount, 0), 10) / 10))
                .stroke(.tint, style: StrokeStyle(lineWidth: max(3, size * 0.14), lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.5), value: amount)
        .accessibilityLabel("Lived lately: \(Int(amount)) out of 10")
    }
}

/// A small ring with a word beside it, for looking back at a "how much" answer.
struct LabeledRing: View {
    let amount: Double // 0 to 10
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            ValueRing(amount: amount, size: 18)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(amount)) out of 10")
    }
}
