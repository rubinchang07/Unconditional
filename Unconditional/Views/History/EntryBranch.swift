import SwiftUI
import SwiftData

/// Your entries as a branch: one branch for each month, growing down the page,
/// with a leaf for every check-in. Heavier entries are deep green-blue leaves,
/// lighter ones are gold, so a month reads at a glance without a list.
/// Tap a leaf and it opens into that entry, like a journal page.
struct EntryBranch: View {
    let entries: [Entry]
    @Namespace private var leaves
    @Environment(\.modelContext) private var context

    var body: some View {
        LazyVStack(spacing: 34) {
            ForEach(BranchMonth.group(entries)) { month in
                VStack(spacing: 10) {
                    Text(month.title)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .softCase()
                    MonthBranch(entries: month.entries, namespace: leaves) { entry in
                        withAnimation(.calm) { context.delete(entry) }
                    }
                }
            }
        }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            if let entry = entries.first(where: { $0.persistentModelID == id }) {
                EntryDetailView(entry: entry)
                    .navigationTransition(.zoom(sourceID: id, in: leaves))
            }
        }
    }
}

/// One month's entries, newest first.
struct BranchMonth: Identifiable {
    let start: Date
    let entries: [Entry]
    var id: Date { start }
    var title: String { start.formatted(.dateTime.month(.wide).year()) }

    static func group(_ entries: [Entry], calendar: Calendar = .current) -> [BranchMonth] {
        let byMonth = Dictionary(grouping: entries) { entry in
            calendar.dateInterval(of: .month, for: entry.createdAt)?.start ?? entry.createdAt
        }
        return byMonth
            .map { BranchMonth(start: $0.key, entries: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.start > $1.start }
    }
}

/// The colors of a leaf, from heavy to light.
enum LeafColor {
    static let heavy = Color(hex: 0x3F7C84)
    static let light = Color(hex: 0xF2B872)
    /// When you didn't say how it sat.
    static let unsaid = Color(hex: 0x9DBF9E)

    static func color(for entry: Entry) -> Color {
        if let lightness = entry.lightness { return heavy.mix(with: light, by: min(max(lightness, 0), 1)) }
        return entry.isGood ? light : unsaid
    }
}

/// A gently swaying stem with leaves on alternating sides.
private struct MonthBranch: View {
    let entries: [Entry]
    let namespace: Namespace.ID
    let onRemove: (Entry) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private let row: CGFloat = 52
    private let width: CGFloat = 240

    private func stemX(_ y: CGFloat) -> CGFloat { width / 2 + sin(y / 80) * 14 }

    var body: some View {
        let height = CGFloat(entries.count) * row + 24
        ZStack(alignment: .topLeading) {
            // The stem, a little thicker at the top where the newest leaves are.
            Canvas { ctx, size in
                var stem = Path()
                stem.move(to: CGPoint(x: stemX(0), y: 0))
                for y in stride(from: CGFloat(0), through: size.height, by: 4) {
                    stem.addLine(to: CGPoint(x: stemX(y), y: y))
                }
                ctx.stroke(stem, with: .color(Color(hex: 0x8A7A62).opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .frame(width: width, height: grown ? height : 0, alignment: .top)
            .clipped()

            ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                let y = CGFloat(index) * row + row / 2 + 6
                let left = index.isMultiple(of: 2)
                NavigationLink(value: entry.persistentModelID) {
                    Leaf()
                        .fill(LeafColor.color(for: entry).gradient)
                        .overlay(Leaf().stroke(.white.opacity(0.35), lineWidth: 0.8))
                        .frame(width: 44, height: 22)
                        .rotationEffect(.degrees(left ? 200 : -20))
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                        .frame(width: 60, height: 44)
                        .contentShape(Rectangle())
                        .matchedTransitionSource(id: entry.persistentModelID, in: namespace)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Remove", systemImage: "minus.circle") { onRemove(entry) }
                }
                .accessibilityLabel(Self.label(for: entry))
                .scaleEffect(grown ? 1 : 0.2, anchor: left ? .trailing : .leading)
                .opacity(grown ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(Double(index) * 0.04), value: grown)
                .position(x: stemX(y) + (left ? -30 : 30), y: y)
                .overlay {
                    Text(entry.createdAt, format: .dateTime.day())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .position(x: stemX(y) + (left ? -76 : 76), y: y)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { grown = true }
        }
    }

    private static func label(for entry: Entry) -> String {
        let date = entry.createdAt.formatted(.dateTime.weekday(.wide).month().day())
        let words = entry.kind.isText ? String(entry.text.prefix(80)) : "A drawing"
        return "\(date). \(words)"
    }
}

/// A simple leaf: two arcs meeting at a point, with a soft midrib.
struct Leaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let tip = CGPoint(x: rect.maxX, y: rect.midY)
        path.move(to: start)
        path.addQuadCurve(to: tip, control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.4))
        path.addQuadCurve(to: start, control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.4))
        path.closeSubpath()
        return path
    }
}
