import SwiftUI
import SwiftData
import NaturalLanguage

/// "Your map": how your loops connect to each other and to your values.
///
/// The app suggests, you decide. A line exists only because you said it feels
/// connected, and its thickness is how much. Roots are your own guesses, never
/// a verdict from the app.
struct MapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]
    @Query private var links: [MapLink]
    @Query private var entries: [Entry]
    @AppStorage("mapRoot") private var root = ""
    @State private var selected: Loop?

    /// Entries needed before the map has enough to go on.
    static let entriesNeeded = 5

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if entries.count < Self.entriesNeeded {
                    let left = Self.entriesNeeded - entries.count
                    GentleEmpty(symbol: "point.3.connected.trianglepath.dotted", title: "Your map grows as you write",
                                message: "After \(left) more check-in\(left == 1 ? "" : "s"), you'll start to see which loops travel together.")
                        .padding(.top, 40)
                } else {
                    MapWeb(loops: loops, values: linkedValues, links: links.filter(\.isConfirmed),
                           color: color(for:), onSelect: { selected = $0 })
                        .aspectRatio(1, contentMode: .fit)
                        .paperCard()

                    HStack(alignment: .top) {
                        Text("Tap a loop to see its core belief and the words you use. Drag a value to move it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Hand placement back to the map.
                        if values.contains(where: { $0.mapX != nil }) {
                            Button("tidy up") {
                                withAnimation(.calm) {
                                    for value in values { value.mapX = nil; value.mapY = nil }
                                }
                            }
                            .font(.footnote)
                        }
                    }

                    ForEach(suggestions, id: \.id) { suggestion in
                        SuggestionCard(suggestion: suggestion) { strength in
                            add(suggestion, strength: strength)
                        } onDismiss: {
                            add(suggestion, strength: 0, status: "dismissed")
                        }
                    }

                    rootCard
                }
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle("your map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { loop in
            LoopMapDetail(loop: loop, loops: loops, values: values, color: color(for: loop))
                .presentationDetents([.large])
        }
        .animation(.calm, value: links.count)
    }

    private var rootCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaperHeading(title: "What might sit underneath", subtitle: nil)
            Text("Looking at these together, is there a belief they might share? Write it as a guess. You can change it any time.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("For example: I'm only worth something if I succeed", text: $root, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        }
        .paperCard()
    }

    /// Only values you've connected to a loop go on the web, so it stays uncluttered.
    private var linkedValues: [PersonalValue] {
        values.filter { value in links.contains { $0.isConfirmed && $0.value == value } }
    }

    private func color(for loop: Loop) -> Color {
        let index = loops.firstIndex(of: loop) ?? 0
        return Color(hex: Loop.palette[index % Loop.palette.count])
    }

    // MARK: - Suggestions

    struct Suggestion {
        let a: Loop
        let b: Loop
        let days: Int
        var id: String { "\(a.persistentModelID.hashValue)-\(b.persistentModelID.hashValue)" }
    }

    /// Pairs of loops that showed up on the same day at least twice, which you
    /// haven't connected or turned down yet. At most three, to keep it calm.
    private var suggestions: [Suggestion] {
        var loopsByDay: [Date: Set<Int>] = [:]
        for entry in entries {
            guard let loop = entry.loop, let index = loops.firstIndex(of: loop) else { continue }
            loopsByDay[Calendar.current.startOfDay(for: entry.createdAt), default: []].insert(index)
        }
        var pairCounts: [[Int]: Int] = [:]
        for day in loopsByDay.values {
            let sorted = day.sorted()
            for i in sorted.indices {
                for j in sorted.indices where j > i {
                    pairCounts[[sorted[i], sorted[j]], default: 0] += 1
                }
            }
        }
        return pairCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .map { Suggestion(a: loops[$0.key[0]], b: loops[$0.key[1]], days: $0.value) }
            .filter { s in !links.contains { $0.value == nil && $0.joins(s.a, s.b) } }
            .prefix(3)
            .map { $0 }
    }

    private func add(_ suggestion: Suggestion, strength: Double, status: String = "confirmed") {
        let link = MapLink()
        context.insert(link)
        link.loopA = suggestion.a
        link.loopB = suggestion.b
        link.strength = strength
        link.status = status
    }
}

// MARK: - The web

/// Values sit in the middle, loops around the outside. Lines are links you
/// confirmed, thicker when they feel stronger.
private struct MapWeb: View {
    let loops: [Loop]
    let values: [PersonalValue]
    let links: [MapLink]
    let color: (Loop) -> Color
    let onSelect: (Loop) -> Void
    /// A value being dragged, and how far it has moved so far.
    @State private var dragging: (id: PersistentIdentifier, offset: CGSize)?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 46
            let auto = MapLayout.spread(values: values, loops: loops, links: links, center: center, outer: outer)
            let positions = values.indices.map { place(values[$0], auto: auto[$0], center: center, outer: outer) }

            ZStack {
                Canvas { ctx, _ in
                    // A faint guide ring, like pencil on paper.
                    let ring = Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
                    ctx.stroke(ring, with: .color(.secondary.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

                    for link in links {
                        guard let a = link.loopA, let ia = loops.firstIndex(of: a) else { continue }
                        let start = point(ia, of: loops.count, radius: outer, center: center)
                        let width = 1 + link.strength * 5
                        let shade = color(a).opacity(0.25 + link.strength * 0.45)
                        var path = Path()
                        if let b = link.loopB, let ib = loops.firstIndex(of: b) {
                            // Loop to loop: a curve that bows toward the middle.
                            let end = point(ib, of: loops.count, radius: outer, center: center)
                            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                            let control = CGPoint(x: (mid.x + center.x) / 2, y: (mid.y + center.y) / 2)
                            path.move(to: start)
                            path.addQuadCurve(to: end, control: control)
                        } else if let value = link.value, let iv = values.firstIndex(of: value) {
                            path.move(to: start)
                            path.addLine(to: positions[iv])
                        }
                        ctx.stroke(path, with: .color(shade), style: StrokeStyle(lineWidth: width, lineCap: .round))
                    }
                }

                ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                    let isDragging = dragging?.id == value.persistentModelID
                    Text(value.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: 76)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Paper.card, in: Capsule())
                        .overlay(Capsule().stroke(.tint.opacity(isDragging ? 0.8 : 0.35)))
                        .scaleEffect(isDragging ? 1.12 : 1)
                        .shadow(color: .black.opacity(isDragging ? 0.15 : 0), radius: 6, y: 3)
                        .position(positions[index])
                        // Drag a value to wherever it reads best. The spot is remembered.
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { drag in
                                    dragging = (value.persistentModelID, drag.translation)
                                }
                                .onEnded { drag in
                                    // Start from where it sat before the drag (positions[index]
                                    // already includes the drag, so adding it again made it jump).
                                    let p = place(value, auto: auto[index], center: center, outer: outer, includingDrag: false)
                                    let end = CGPoint(x: p.x + drag.translation.width, y: p.y + drag.translation.height)
                                    let spot = MapLayout.clamp(end, center: center, limit: outer * MapLayout.dragLimit)
                                    value.mapX = Double((spot.x - center.x) / outer)
                                    value.mapY = Double((spot.y - center.y) / outer)
                                    dragging = nil
                                }
                        )
                        .zIndex(isDragging ? 1 : 0)
                        .animation(.spring(duration: 0.3), value: isDragging)
                        .sensoryFeedback(.selection, trigger: isDragging)
                        .accessibilityHint("Drag to move it on your map")
                }

                ForEach(Array(loops.enumerated()), id: \.element.id) { index, loop in
                    Button { onSelect(loop) } label: {
                        VStack(spacing: 4) {
                            // Loops are rings here too, matching Patterns.
                            MiniRing(color: color(loop))
                                .frame(width: dotSize(loop) + 6, height: dotSize(loop) + 6)
                            Text(loop.name)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                                .frame(width: 84)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(point(index, of: loops.count, radius: outer, center: center))
                    .accessibilityLabel("\(loop.name), \(loop.entries.count) entries")
                    .accessibilityHint("Shows its core belief and connections")
                }
            }
        }
    }

    /// Where a value is drawn: where you put it, or where the map placed it,
    /// plus any drag in progress.
    private func place(_ value: PersonalValue, auto: CGPoint, center: CGPoint, outer: CGFloat,
                       includingDrag: Bool = true) -> CGPoint {
        var p = auto
        if let x = value.mapX, let y = value.mapY {
            p = CGPoint(x: center.x + CGFloat(x) * outer, y: center.y + CGFloat(y) * outer)
        }
        if includingDrag, let dragging, dragging.id == value.persistentModelID {
            p.x += dragging.offset.width
            p.y += dragging.offset.height
            // Held inside the map while dragging, so letting go never makes it jump.
            p = MapLayout.clamp(p, center: center, limit: outer * MapLayout.dragLimit)
        }
        return p
    }

    /// Bigger dot for a loop that comes up more, within a gentle range.
    private func dotSize(_ loop: Loop) -> CGFloat {
        18 + CGFloat(min(loop.entries.count, 20))
    }

    private func point(_ index: Int, of count: Int, radius: CGFloat, center: CGPoint, offset: Double = 0) -> CGPoint {
        guard count > 0 else { return center }
        let angle = -Double.pi / 2 + 2 * Double.pi * (Double(index) + offset) / Double(count)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

// MARK: - Placing values

/// Spreads values out so their labels don't overlap, and nudges each one
/// toward the loops it's linked to so lines stay short and cross less.
enum MapLayout {
    /// Room a value label needs around it.
    static let labelWidth: CGFloat = 92
    static let labelHeight: CGFloat = 30
    /// How far from the middle you can drag a value, as a share of the map's radius.
    static let dragLimit: CGFloat = 0.82

    static func spread(values: [PersonalValue], loops: [Loop], links: [MapLink],
                       center: CGPoint, outer: CGFloat) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        if values.count == 1 { return [center] }

        // Start evenly around a ring in the middle.
        let ring = outer * 0.42
        var points: [CGPoint] = values.indices.map { i in
            let angle = -Double.pi / 2 + 2 * Double.pi * (Double(i) + 0.5) / Double(values.count)
            return CGPoint(x: center.x + ring * cos(angle), y: center.y + ring * sin(angle))
        }

        // Where each value's linked loops sit, so it can lean toward them.
        let loopPoints: [CGPoint] = loops.indices.map { i in
            let angle = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(loops.count)
            return CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle))
        }
        let targets: [CGPoint?] = values.map { value in
            let linked = links.compactMap { link -> CGPoint? in
                guard link.value == value, let loop = link.loopA, let i = loops.firstIndex(of: loop) else { return nil }
                return loopPoints[i]
            }
            guard !linked.isEmpty else { return nil }
            let x = linked.map(\.x).reduce(0, +) / CGFloat(linked.count)
            let y = linked.map(\.y).reduce(0, +) / CGFloat(linked.count)
            return CGPoint(x: x, y: y)
        }

        for _ in 0..<80 {
            // Lean a little toward linked loops, but stay well inside the ring of loops.
            for i in points.indices {
                if let target = targets[i] {
                    points[i].x += (target.x - points[i].x) * 0.02
                    points[i].y += (target.y - points[i].y) * 0.02
                }
            }
            // Push apart any two labels that overlap.
            for i in points.indices {
                for j in points.indices where j > i {
                    let dx = points[j].x - points[i].x
                    let dy = points[j].y - points[i].y
                    let overlapX = labelWidth - abs(dx)
                    let overlapY = labelHeight - abs(dy)
                    guard overlapX > 0, overlapY > 0 else { continue }
                    // Separate along whichever way needs less movement.
                    if overlapX / labelWidth < overlapY / labelHeight {
                        let push = overlapX / 2 * (dx >= 0 ? 1 : -1)
                        points[i].x -= push
                        points[j].x += push
                    } else {
                        let push = overlapY / 2 * (dy >= 0 ? 1 : -1)
                        points[i].y -= push
                        points[j].y += push
                    }
                }
            }
            for i in points.indices {
                points[i] = clamp(points[i], center: center, limit: outer * 0.7)
            }
        }
        return points
    }

    /// Keeps a point within `limit` of the center.
    static func clamp(_ point: CGPoint, center: CGPoint, limit: CGFloat) -> CGPoint {
        let dx = point.x - center.x, dy = point.y - center.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > limit, distance > 0 else { return point }
        return CGPoint(x: center.x + dx / distance * limit, y: center.y + dy / distance * limit)
    }
}

// MARK: - A suggestion

private struct SuggestionCard: View {
    let suggestion: MapView.Suggestion
    let onConnect: (Double) -> Void
    let onDismiss: () -> Void
    @State private var strength = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(suggestion.a.name) and \(suggestion.b.name) showed up on the same day \(suggestion.days) times. Do they feel connected?")
                .font(.callout)
            RatingSlider(title: "How connected", value: $strength, range: 0.05...1, step: 0.05,
                         lowLabel: "a little", highLabel: "very", valueText: MapLink.strengthLabel)
            HStack {
                Button("Not really", action: onDismiss)
                    .buttonStyle(.bordered)
                    .softCase()
                Spacer()
                Button("Connect them") { onConnect(strength) }
                    .buttonStyle(.paper)
            }
        }
        .paperCard()
    }
}

extension MapLink {
    static func strengthLabel(_ value: Double) -> String {
        switch value {
        case ..<0.05: "not linked"
        case ..<0.35: "a little"
        case ..<0.7: "somewhat"
        default: "strongly"
        }
    }
}

// MARK: - One loop up close

private struct LoopMapDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let loop: Loop
    let loops: [Loop]
    let values: [PersonalValue]
    let color: Color
    /// Its own query, so a new link shows up here straight away while you slide.
    @Query private var links: [MapLink]
    @State private var words: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(loop.coreBelief.isEmpty ? "No core belief written yet." : loop.coreBelief)
                        .font(.system(.body, design: .serif))
                } header: {
                    Text("Core belief")
                } footer: {
                    Text("The belief this loop runs on, in your words. You can edit it in Settings → Your loops.")
                }

                Section {
                    if words.isEmpty {
                        Text("After a few more written entries in this loop, the words you keep using will show here.")
                            .foregroundStyle(.secondary)
                    } else {
                        FlowWords(words: words, color: color)
                    }
                } header: {
                    Text("Words that keep coming up")
                } footer: {
                    Text("Found on your phone. Nothing leaves it.")
                }

                Section {
                    if values.isEmpty {
                        Text("Add values in Anchors, then connect them here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(values) { value in
                        RatingSlider(title: value.name, value: valueBinding(value), range: 0...1, step: 0.05,
                                     lowLabel: "not really", highLabel: "a lot", valueText: MapLink.strengthLabel)
                    }
                } header: {
                    Text("Values underneath")
                } footer: {
                    Text("A loop often hurts because it touches something you care about. How much does this one touch each value?")
                }

                Section {
                    ForEach(loops.filter { $0 != loop }) { other in
                        RatingSlider(title: other.name, value: loopBinding(other), range: 0...1, step: 0.05,
                                     lowLabel: "not really", highLabel: "a lot", valueText: MapLink.strengthLabel)
                    }
                } header: {
                    Text("Connected loops")
                }
            }
            .navigationTitle(loop.name.lowercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { words = RecurringWords.top(in: loop.entries) }
        }
    }

    private func valueBinding(_ value: PersonalValue) -> Binding<Double> {
        binding(for: links.first { $0.loopA == loop && $0.value == value }) { link in
            link.loopA = loop
            link.value = value
        }
    }

    private func loopBinding(_ other: Loop) -> Binding<Double> {
        binding(for: links.first { $0.value == nil && $0.joins(loop, other) }) { link in
            link.loopA = loop
            link.loopB = other
        }
    }

    /// Slide up from zero to create a link, back to zero to remove it.
    private func binding(for existing: MapLink?, attach: @escaping (MapLink) -> Void) -> Binding<Double> {
        Binding {
            guard let existing, existing.isConfirmed else { return 0 }
            return existing.strength
        } set: { newValue in
            if let existing {
                if newValue < 0.05 {
                    context.delete(existing)
                } else {
                    existing.strength = newValue
                    existing.status = "confirmed"
                }
            } else if newValue >= 0.05 {
                let link = MapLink()
                context.insert(link)
                attach(link)
                link.strength = newValue
            }
        }
    }
}

/// Simple wrapping chips for the recurring words.
private struct FlowWords: View {
    let words: [String]
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(words, id: \.self) { word in
                Text(word)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(color.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

/// Finds the words you use most in a loop's entries, with Apple's on-device
/// NaturalLanguage framework. "Wasting", "wasted" and "waste" count as one.
enum RecurringWords {
    private static let ignored: Set<String> = [
        "feel", "think", "know", "like", "want", "really", "thing", "something", "today", "just", "make",
        "going", "maybe", "still", "time", "even", "keep", "much", "said", "would", "could", "should",
        "need", "always", "never", "people", "everything", "anything", "lot", "way", "day", "get", "have",
        "be", "do", "go", "say", "see", "come", "take", "feeling",
    ]

    static func top(in entries: [Entry], limit: Int = 8) -> [String] {
        let text = entries.filter { $0.kind.isText }.map(\.text).joined(separator: "\n")
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        var counts: [String: Int] = [:]
        let kept: Set<NLTag> = [.noun, .verb, .adjective]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
            guard let tag, kept.contains(tag) else { return true }
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            let word = (lemma ?? String(text[range])).lowercased()
            if word.count >= 4, !ignored.contains(word) {
                counts[word, default: 0] += 1
            }
            return true
        }
        return counts.filter { $0.value >= 2 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }
}
