import SwiftUI
import SwiftData
import Charts

/// Patterns over time. Everything here *describes* what happened. Nothing is a
/// score of how you're doing, and the wording avoids "better" or "worse".
struct PatternsView: View {
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @Query(sort: \Reframe.createdAt) private var reframes: [Reframe]
    @Query(sort: \Win.createdAt) private var wins: [Win]
    @Query(sort: \TinyStep.createdAt) private var tinySteps: [TinyStep]
    @Query(sort: \CareerReflection.createdAt) private var career: [CareerReflection]

    enum Span: Int, CaseIterable, Identifiable {
        case fourWeeks = 28, twelveWeeks = 84
        var id: Int { rawValue }
        var label: String { self == .fourWeeks ? "4 weeks" : "12 weeks" }
        var days: Int { rawValue }
    }
    @State private var span: Span = .fourWeeks
    @AppStorage(CareerReflection.enabledKey) private var careerEnabled = false

    private var start: Date { Date.now.addingTimeInterval(-Double(span.days) * 86_400) }
    private var previousStart: Date { start.addingTimeInterval(-Double(span.days) * 86_400) }

    private func inSpan(_ date: Date) -> Bool { date >= start }

    var body: some View {
        List {
            Section {
                Picker("Time span", selection: $span) {
                    ForEach(Span.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            } footer: {
                Text("These describe what happened. They aren't a score of how you're doing, and they'll keep changing.")
            }

            if entries.filter({ inSpan($0.createdAt) }).count + reframes.filter({ inSpan($0.createdAt) }).count < 3 {
                GentleEmpty(symbol: "chart.line.uptrend.xyaxis", title: "Patterns need a little time",
                            message: "After a few check-ins, you'll start to see how things shift from week to week.")
                    .listRowBackground(Color.clear)
            } else {
                loopsSection
                reframeSection
                timeOfDaySection
                stepsAndWinsSection
                if careerEnabled { careerSection }
            }

            Section {
                NavigationLink {
                    ParkedReviewView()
                } label: {
                    Label("Weekly review", systemImage: "tray")
                }
                if careerEnabled {
                    NavigationLink {
                        CareerHistoryView()
                    } label: {
                        Label("Career reflections", systemImage: "briefcase")
                    }
                }
            }
        }
        .themedBackground()
        .paperList()
        .animation(.calm, value: span)
    }

    // MARK: - Loops by week

    /// Soft colors for the loops, in their order. "Not sure yet" is grey.
    private static let loopColors: [Color] = Loop.palette.map { Color(hex: $0) }
    private static let unsure = "Not sure yet"

    /// "Falling behind came up less often than the 4 weeks before (3, down from 7)."
    private var loopComparisons: [String] {
        loops.compactMap { loop in
            let now = loop.entries.filter { inSpan($0.createdAt) }.count
            let before = loop.entries.filter { $0.createdAt >= previousStart && $0.createdAt < start }.count
            guard now + before > 0 else { return nil }
            if now == before { return "\(loop.name): about the same (\(now))." }
            if before == 0 { return "\(loop.name): showed up \(now) time\(now == 1 ? "" : "s"), not at all the \(span.label) before." }
            return now < before
                ? "\(loop.name): came up less often (\(now), down from \(before))."
                : "\(loop.name): came up more often (\(now), up from \(before))."
        }
    }

    private var loopsSection: some View {
        let counted = loops.map { loop in
            (loop: loop,
             now: loop.entries.filter { inSpan($0.createdAt) }.count,
             before: loop.entries.filter { $0.createdAt >= previousStart && $0.createdAt < start }.count)
        }
        .filter { $0.now > 0 }
        .sorted { $0.now > $1.now }
        let maxCount = counted.map(\.now).max() ?? 0

        return Section {
            if counted.isEmpty {
                Text("No loops named in this time. That's fine too.")
                    .foregroundStyle(.secondary)
            } else {
                BubbleCluster {
                    ForEach(counted.indices, id: \.self) { index in
                        let item = counted[index]
                        LoopBubble(name: item.loop.name, count: item.now, previous: item.before,
                                   maxCount: maxCount, color: color(for: item.loop))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .contain)
                .accessibilityHint(loopComparisons.joined(separator: " "))
            }
        } header: {
            Text("Loops")
        } footer: {
            Text("Bigger means it came up more. Arrows compare with the \(span.label) before. More often might just mean you noticed it more.")
        }
    }

    private func color(for loop: Loop) -> Color {
        let index = loops.firstIndex(of: loop) ?? 0
        return Self.loopColors[index % Self.loopColors.count]
    }

    // MARK: - Reframes over time

    private struct RatingPoint: Identifiable {
        let date: Date
        let value: Double
        let series: String
        var id: String { "\(date.timeIntervalSince1970)-\(series)" }
    }

    private var spanReframes: [Reframe] { reframes.filter { inSpan($0.createdAt) } }

    @ViewBuilder
    private var reframeSection: some View {
        let items = spanReframes
        if !items.isEmpty {
            let before = items.map(\.distressBefore).reduce(0, +) / Double(items.count)
            let after = items.map(\.distressAfter).reduce(0, +) / Double(items.count)
            let beliefBefore = items.map(\.beliefBefore).reduce(0, +) / Double(items.count)
            let beliefAfter = items.map(\.beliefAfter).reduce(0, +) / Double(items.count)

            Section {
                DistressOrbs(before: before, after: after)
                BeliefBars(before: beliefBefore, after: beliefAfter)
                    .padding(.vertical, 6)
            } header: {
                Text("When you reframe")
            } footer: {
                Text("Averages across \(items.count) reframe\(items.count == 1 ? "" : "s"). Some days a reframe shifts a lot, some days barely. Both are normal.")
            }
        }
    }

    // MARK: - Time of day

    private enum DayPart: String, CaseIterable {
        case morning = "Morning", afternoon = "Afternoon", evening = "Evening", lateNight = "Late night"

        init(hour: Int) {
            switch hour {
            case 5..<12: self = .morning
            case 12..<17: self = .afternoon
            case 17..<21: self = .evening
            default: self = .lateNight
            }
        }
    }

    @ViewBuilder
    private var timeOfDaySection: some View {
        let spanEntries = entries.filter { inSpan($0.createdAt) }
        let hours = (0..<24).map { hour in
            spanEntries.filter { Calendar.current.component(.hour, from: $0.createdAt) == hour }.count
        }
        let counts = Dictionary(grouping: spanEntries) { DayPart(hour: Calendar.current.component(.hour, from: $0.createdAt)) }
            .mapValues(\.count)
        if let busiest = counts.max(by: { $0.value < $1.value })?.key {
            Section {
                ZStack {
                    ClockDial(hours: hours)
                    VStack(spacing: 2) {
                        Text("mostly").font(.caption).foregroundStyle(.secondary)
                        Text(busiest.rawValue.lowercased())
                            .font(.system(.title3, design: .serif).weight(.semibold))
                    }
                }
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } header: {
                Text("When you check in")
            } footer: {
                if busiest == .lateNight {
                    Text("Loops often get louder when you're tired, so be gentle with what feels true at that hour.")
                }
            }
        }
    }

    // MARK: - Tiny steps and wins

    @ViewBuilder
    private var stepsAndWinsSection: some View {
        let steps = tinySteps.filter { inSpan($0.createdAt) }
        let tried = steps.filter { $0.outcome == "tried" }.count
        let spanWins = wins.filter { inSpan($0.createdAt) }
        let effortLeaning = spanWins.filter { $0.effortToOutcome < 0.4 }.count

        if !steps.isEmpty || !spanWins.isEmpty {
            Section {
                if !steps.isEmpty {
                    Label("You gave \(tried) of \(steps.count) tiny step\(steps.count == 1 ? "" : "s") a go.", systemImage: "shoe.2")
                }
                if !spanWins.isEmpty {
                    Label("You logged \(spanWins.count) win\(spanWins.count == 1 ? "" : "s"), and \(effortLeaning) leaned toward effort.", systemImage: "star")
                }
            } header: {
                Text("Steps and wins")
            } footer: {
                Text("Trying counts the same here, whatever happened next.")
            }
        }
    }

    // MARK: - Career

    @ViewBuilder
    private var careerSection: some View {
        let items = career.filter { inSpan($0.createdAt) }
        if items.count >= 2 {
            let points = items.flatMap {
                [RatingPoint(date: $0.createdAt, value: $0.enjoyment, series: "Enjoyed the work"),
                 RatingPoint(date: $0.createdAt, value: $0.discouragement, series: "Felt discouraged")]
            }
            Section {
                Chart(points) { point in
                    LineMark(x: .value("Day", point.date, unit: .day),
                             y: .value("Rating", point.value))
                        .foregroundStyle(by: .value("Feeling", point.series))
                        .interpolationMethod(.catmullRom)
                }
                .chartForegroundStyleScale(domain: ["Enjoyed the work", "Felt discouraged"],
                                           range: [Color(hex: 0x7FA383), Color(hex: 0x9B86C4)])
                .chartYScale(domain: 0...10)
                .chartYAxis { AxisMarks(values: [0, 5, 10]) }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 180)
                .padding(.vertical, 8)
            } header: {
                Text("Career: enjoyment and discouragement")
            } footer: {
                Text("When these move separately, it's a clue. Enjoying the work while feeling discouraged is different from not enjoying it.")
            }
        }
    }

    private func one(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}
