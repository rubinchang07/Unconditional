import SwiftUI
import SwiftData

/// "On your mind lately": one question, answered with orbs.
///
/// Each loop is an orb, sized by how often it came up in the last four weeks.
/// A faint ring around it shows how big it was the four weeks before, so you
/// can see at a glance whether it grew or eased. Tap one for a plain sentence.
/// Good moments get a warm orb too. Nothing here is a score.
struct PatternsView: View {
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @State private var chosen: String?

    var body: some View {
        let trends = LoopTrend.trends(entries: entries, loops: loops)
        ScrollView {
            VStack(spacing: 28) {
                Text("What's been on your mind lately?")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .softCase()
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                if trends.isEmpty {
                    Text("After a few check-ins, your loops will gather here.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                } else {
                    let biggest = trends.map { max($0.recent, $0.before) }.max() ?? 1
                    BubbleCluster(spacing: 18) {
                        ForEach(trends) { trend in
                            Button {
                                withAnimation(.calm) { chosen = chosen == trend.id ? nil : trend.id }
                            } label: {
                                TrendOrb(trend: trend, biggest: biggest, color: color(for: trend),
                                         isChosen: chosen == trend.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(trend.sentence)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // One sentence: the loop you tapped, or else what changed most.
                    Text((trends.first { $0.id == chosen } ?? LoopTrend.headline(trends)).sentence)
                        .font(.system(.title3, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 12)
                        .contentTransition(.opacity)
                        .id(chosen)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .themedBackground()
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle("on your mind")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let loopColors: [Color] = Loop.palette.map { Color(hex: $0) }

    private func color(for trend: LoopTrend) -> Color {
        if trend.isGood { return Color(hex: 0xF2B872) }
        let index = loops.firstIndex { $0.name == trend.name } ?? 0
        return Self.loopColors[index % Self.loopColors.count]
    }
}

/// One loop's orb, with a faint ring for the month before.
private struct TrendOrb: View {
    let trend: LoopTrend
    let biggest: Int
    let color: Color
    let isChosen: Bool

    private let maxSize: CGFloat = 110

    private func size(_ count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return maxSize * (0.35 + 0.65 * CGFloat(count) / CGFloat(max(biggest, 1)))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if trend.before > 0 {
                    Circle()
                        .strokeBorder(color.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        .frame(width: size(trend.before), height: size(trend.before))
                }
                if trend.recent > 0 {
                    MiniOrb(color: color, seed: Double(trend.name.count))
                        .frame(width: size(trend.recent), height: size(trend.recent))
                }
            }
            .frame(width: maxSize, height: maxSize)
            .scaleEffect(isChosen ? 1.06 : 1)
            Text(trend.name)
                .font(.caption)
                .foregroundStyle(isChosen ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: maxSize)
        }
    }
}

/// How often one loop came up in the last four weeks, against the four weeks before.
struct LoopTrend: Identifiable, Equatable {
    let name: String
    let recent: Int
    let before: Int
    var isGood = false
    var id: String { (isGood ? "good:" : "loop:") + name }

    static let days = 28

    static func trends(entries: [Entry], loops: [Loop], now: Date = .now) -> [LoopTrend] {
        let start = now.addingTimeInterval(-Double(days) * 86_400)
        let previousStart = start.addingTimeInterval(-Double(days) * 86_400)
        func counts(_ matching: (Entry) -> Bool) -> (Int, Int) {
            let mine = entries.filter(matching)
            return (mine.filter { $0.createdAt >= start && $0.createdAt <= now }.count,
                    mine.filter { $0.createdAt >= previousStart && $0.createdAt < start }.count)
        }
        var result = loops.compactMap { loop -> LoopTrend? in
            let (recent, before) = counts { $0.loop == loop }
            return recent + before > 0 ? LoopTrend(name: loop.name, recent: recent, before: before) : nil
        }
        .sorted { $0.recent > $1.recent }
        let (good, goodBefore) = counts(\.isGood)
        if good + goodBefore > 0 {
            result.append(LoopTrend(name: "good moments", recent: good, before: goodBefore, isGood: true))
        }
        return result
    }

    /// What changed the most, for when nothing is tapped.
    static func headline(_ trends: [LoopTrend]) -> LoopTrend {
        trends.max { abs($0.recent - $0.before) < abs($1.recent - $1.before) } ?? trends[0]
    }

    /// In plain words, never better or worse.
    var sentence: String {
        let what = isGood ? "Good moments" : name
        if before == 0 { return "\(what) came up this month, and not the month before." }
        if recent == 0 { return "\(what) didn't come up this month." }
        let difference = Double(recent - before) / Double(max(before, 1))
        if abs(difference) < 0.25 { return "\(what) came up about as often as the month before." }
        return recent > before
            ? "\(what) came up more than the month before. Sometimes that just means you noticed it more."
            : "\(what) came up less than the month before."
    }
}
