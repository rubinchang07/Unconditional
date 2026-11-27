import SwiftUI
import SwiftData

/// One place for looking back. It opens on a sentence or two about the month,
/// in plain words, then head and heart from recent reframes as small waves.
struct InsightsView: View {
    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @Query(sort: \Reframe.createdAt) private var reframes: [Reframe]
    /// Career check-ins became an ordinary check-in starting point. Older ones stay readable here.
    @Query private var careerReflections: [CareerReflection]
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight

    /// Head-and-heart reframes from the last four weeks, oldest first.
    private var headAndHeart: [Reframe] {
        let start = Date.now.addingTimeInterval(-Double(InsightSummary.days) * 86_400)
        return reframes.filter { $0.hasHeadAndHeart && $0.createdAt >= start && $0.entry != nil }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 18) {
                    OrbView(palette: orbPalette, speed: 0.5, state: .settling)
                        .frame(width: 90, height: 90)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(InsightSummary.sentences(entries: entries, reframes: reframes), id: \.self) { sentence in
                            Text(sentence)
                                .font(.system(.title3, design: .serif))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
            } header: {
                Text("This month")
            } footer: {
                Text("A description, never a score.")
            }

            if !headAndHeart.isEmpty {
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(headAndHeart) { reframe in
                                if let entry = reframe.entry {
                                    NavigationLink { EntryDetailView(entry: entry) } label: {
                                        TinyWaves(head: reframe.headValue, heart: reframe.heartValue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollIndicators(.hidden)
                    // Opens on the newest, at the right end.
                    .defaultScrollAnchor(.trailing)
                } header: {
                    Text("Head and heart lately")
                } footer: {
                    Text("Calm waves: they agreed. Wobbly: they were apart. Tap one to see it.")
                }
            }

            Section {
                NavigationLink {
                    PatternsView()
                } label: {
                    Label("On your mind lately", systemImage: "circle.dashed")
                }
            } footer: {
                Text("Which loops have come up more or less lately.")
            }

            if !careerReflections.isEmpty {
            Section {
                if !careerReflections.isEmpty {
                    NavigationLink {
                        CareerHistoryView()
                    } label: {
                        Label("Career reflections", systemImage: "briefcase")
                    }
                }
            }
            }
        }
        .themedBackground()
        .paperList()
        // Room at the end, so the floating tab bar never sits over the last card.
        .contentMargins(.bottom, 80, for: .scrollContent)
        .navigationTitle("insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One past reframe's head and heart, as a tiny still pair of waves: no labels,
/// no numbers. Calm when they agreed, wobbly when they were apart.
struct TinyWaves: View {
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight
    let head: Double
    let heart: Double

    var body: some View {
        let colors = orbPalette.colors
        let gap = HeadAndHeart.gap(head: head, heart: heart)
        DissonanceWaves(gap: gap, headColor: colors.first ?? .teal, heartColor: colors.last ?? .orange, reduceMotion: true)
            .frame(width: 64, height: 36)
            .padding(8)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(gap >= HeadAndHeart.noticeable ? "Head and heart apart" : "Head and heart in tune")
    }
}

/// A sentence or two about the last four weeks, in ordinary words.
/// Descriptive only: it says what happened, never whether that's good or bad.
enum InsightSummary {
    static let days = 28

    static func sentences(entries: [Entry], reframes: [Reframe], now: Date = .now) -> [String] {
        let start = now.addingTimeInterval(-Double(days) * 86_400)
        let previousStart = start.addingTimeInterval(-Double(days) * 86_400)
        let recent = entries.filter { $0.createdAt >= start && $0.createdAt <= now }
        // Only older reframes asked heaviness twice; newer ones compare head and heart instead.
        let recentReframes = reframes.filter { $0.createdAt >= start && $0.createdAt <= now && !$0.hasHeadAndHeart }
        let recentHeadHeart = reframes.filter { $0.createdAt >= start && $0.createdAt <= now && $0.hasHeadAndHeart }

        guard recent.count >= 3 else {
            return ["After a few more check-ins, a sentence or two about your month will show up here."]
        }

        var result: [String] = []

        // 1. The loop that came up most, and when.
        let byLoop = Dictionary(grouping: recent.filter { $0.loop != nil }) { $0.loop!.name }
        if let top = byLoop.max(by: { a, b in a.value.count == b.value.count ? a.key > b.key : a.value.count < b.value.count }), top.value.count >= 2 {
            let name = top.key
            let items = top.value
            let before = entries.filter {
                $0.loop?.name == name && $0.createdAt >= previousStart && $0.createdAt < start
            }.count
            var sentence = "\(name) came up most this month"
            if let part = usualTime(of: items) { sentence += ", usually \(part)" }
            if before > items.count { sentence += ", though less than the month before" }
            result.append(sentence + ".")
        }

        // 2. Reframes, or good moments if there weren't enough reframes to say anything.
        if recentHeadHeart.count >= 2 {
            let apart = recentHeadHeart.filter { HeadAndHeart.gap(head: $0.headValue, heart: $0.heartValue) >= HeadAndHeart.noticeable }.count
            result.append(apart * 2 > recentHeadHeart.count
                ? "When you reframed, your head and heart were often apart. Understanding often arrives first."
                : "When you reframed, your head and heart mostly agreed.")
        } else if recentReframes.count >= 2 {
            let before = recentReframes.map(\.distressBefore).reduce(0, +) / Double(recentReframes.count)
            let after = recentReframes.map(\.distressAfter).reduce(0, +) / Double(recentReframes.count)
            result.append(after < before - 0.5
                ? "After reframing, the distress usually eased a little."
                : "Reframing shifted things only a little this month. That's normal too.")
        } else if recent.contains(where: \.isGood) {
            result.append("You also kept some good moments.")
        }

        if result.isEmpty {
            result.append("You checked in \(recent.count) times this month. Patterns take a little longer to show.")
        }
        return Array(result.prefix(2))
    }

    /// "in the mornings", "late at night", and so on, if at least half the entries share one.
    private static func usualTime(of entries: [Entry]) -> String? {
        let parts = entries.map { entry -> String in
            switch Calendar.current.component(.hour, from: entry.createdAt) {
            case 5..<12: "in the mornings"
            case 12..<17: "in the afternoons"
            case 17..<21: "in the evenings"
            default: "late at night"
            }
        }
        let counts = Dictionary(grouping: parts) { $0 }.mapValues(\.count)
        guard let top = counts.max(by: { $0.value < $1.value }), Double(top.value) / Double(parts.count) >= 0.5 else { return nil }
        return top.key
    }
}
