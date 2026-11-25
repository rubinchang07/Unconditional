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
    /// Show every loop, not just the ones that fit comfortably.
    @State private var showAllLoops = false

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
                    let shown = showAllLoops ? loops : MapLayout.visibleLoops(loops, links: links)
                    MapWeb(loops: shown, values: linkedValues, links: links.filter(\.isConfirmed),
                           color: color(for:), onSelect: { selected = $0 })
                        .aspectRatio(1, contentMode: .fit)
                        .paperCard()

                    // Quieter loops are one tap away, so the map never gets crowded.
                    if loops.count > MapLayout.loopLimit, shown.count < loops.count || showAllLoops {
                        let hidden = loops.count - MapLayout.visibleLoops(loops, links: links).count
                        Button(showAllLoops ? "show fewer loops" : "+\(hidden) quieter \(hidden == 1 ? "loop" : "loops")") {
                            withAnimation(.calm) { showAllLoops.toggle() }
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(alignment: .top) {
                        Text("Tap a loop or value to light up what it's connected to, and tap a lit loop again to open it. Drag a value to move it.")
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
        .contentMargins(.bottom, 80, for: .scrollContent)
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
    /// The loop or value you tapped. Its connections stay lit and the rest fades back.
    @State private var focus: PersistentIdentifier?

    /// Everything directly connected to the focus, including the focus itself.
    private var lit: Set<PersistentIdentifier> {
        guard let focus else { return [] }
        var ids: Set<PersistentIdentifier> = [focus]
        for link in links where involves(link, focus) {
            for id in [link.loopA?.persistentModelID, link.loopB?.persistentModelID, link.value?.persistentModelID] {
                if let id { ids.insert(id) }
            }
        }
        return ids
    }

    private func involves(_ link: MapLink, _ id: PersistentIdentifier) -> Bool {
        link.loopA?.persistentModelID == id || link.loopB?.persistentModelID == id || link.value?.persistentModelID == id
    }

    /// How strongly to draw a node: full when nothing is focused or it's connected.
    private func presence(_ id: PersistentIdentifier) -> Double {
        focus == nil || lit.contains(id) ? 1 : 0.25
    }

    private func toggleFocus(_ id: PersistentIdentifier) {
        withAnimation(.calm) { focus = focus == id ? nil : id }
    }

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
                        let faded = focus.map { !involves(link, $0) } ?? false
                        let shade = color(a).opacity((0.25 + link.strength * 0.45) * (faded ? 0.12 : 1))
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
                // Tapping empty space lets everything come back.
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.calm) { focus = nil } }

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
                        .opacity(isDragging ? 1 : presence(value.persistentModelID))
                        .position(positions[index])
                        .onTapGesture { toggleFocus(value.persistentModelID) }
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
                        .accessibilityAddTraits(focus == value.persistentModelID ? [.isButton, .isSelected] : .isButton)
                        .accessibilityHint("Tap to light up its connections. Drag to move it on your map.")
                }

                ForEach(Array(loops.enumerated()), id: \.element.id) { index, loop in
                    // First tap lights up its connections; a second tap opens it.
                    Button {
                        if focus == loop.persistentModelID {
                            onSelect(loop)
                        } else {
                            toggleFocus(loop.persistentModelID)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            // Loops are rings here too, matching Patterns.
                            MiniRing(color: color(loop))
                                .frame(width: MapLayout.dotSize(loop) + 6, height: MapLayout.dotSize(loop) + 6)
                            Text(loop.name)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                                .frame(width: 84)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(presence(loop.persistentModelID))
                    .position(point(index, of: loops.count, radius: outer, center: center))
                    .accessibilityLabel("\(loop.name), \(loop.entries.count) entries")
                    .accessibilityAddTraits(focus == loop.persistentModelID ? .isSelected : [])
                    .accessibilityHint(focus == loop.persistentModelID ? "Opens its core belief and words" : "Lights up its connections")
                    .accessibilityAction(named: "Open") { onSelect(loop) }
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
    /// About how many loop labels fit around the ring on an iPhone.
    static let loopLimit = 8

    /// The loops to show: every loop you've linked to something (so a connection
    /// never disappears), then the ones that came up most in the last three months,
    /// up to `loopLimit`. Kept in your own order.
    static func visibleLoops(_ loops: [Loop], links: [MapLink], now: Date = .now) -> [Loop] {
        guard loops.count > loopLimit else { return loops }
        let confirmed = links.filter(\.isConfirmed)
        let linked = loops.filter { loop in confirmed.contains { $0.loopA == loop || $0.loopB == loop } }
        let since = now.addingTimeInterval(-90 * 86_400)
        func recent(_ loop: Loop) -> Int { loop.entries.filter { $0.createdAt >= since }.count }
        let others = loops.filter { !linked.contains($0) }
            .sorted { recent($0) == recent($1) ? $0.sortOrder < $1.sortOrder : recent($0) > recent($1) }
        let chosen = linked + others.prefix(max(loopLimit - linked.count, 0))
        return loops.filter { chosen.contains($0) }
    }

    /// How far from the middle you can drag a value, as a share of the map's radius.
    static let dragLimit: CGFloat = 0.82

    /// Bigger ring for a loop that comes up more, within a gentle range.
    static func dotSize(_ loop: Loop) -> CGFloat {
        18 + CGFloat(min(loop.entries.count, 20))
    }

    /// About how much room a loop's ring and name take, so values can keep clear of it.
    static func loopBox(_ loop: Loop) -> CGSize {
        let textWidth = CGFloat(loop.name.count) * 6.2
        let lines: CGFloat = textWidth > 84 ? 2 : 1
        return CGSize(width: min(84, textWidth) + 10, height: dotSize(loop) + 6 + 4 + lines * 14 + 6)
    }

    /// Places each value label in the free spot closest to where it would like to be:
    /// evenly around the middle, leaning toward the loops it's linked to. Loop labels and
    /// values you've moved yourself are treated as taken, so nothing lands on top of them.
    /// Only when the map is truly full does a label overlap, and then as little as possible.
    static func spread(values: [PersonalValue], loops: [Loop], links: [MapLink],
                       center: CGPoint, outer: CGFloat) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        func ringPoint(_ i: Int, of count: Int, radius: CGFloat, turn: Double = 0) -> CGPoint {
            let angle = -Double.pi / 2 + 2 * Double.pi * (Double(i) + turn) / Double(count)
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        func box(_ point: CGPoint, _ size: CGSize) -> CGRect {
            CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        }
        let valueSize = CGSize(width: labelWidth, height: labelHeight)

        let loopPoints = loops.indices.map { ringPoint($0, of: loops.count, radius: outer) }
        var taken: [CGRect] = loops.indices.map { box(loopPoints[$0], loopBox(loops[$0])) }

        // Values you've placed by hand stay put, and the rest keep clear of them.
        let manual: [CGPoint?] = values.map { value in
            guard let x = value.mapX, let y = value.mapY else { return nil }
            return CGPoint(x: center.x + CGFloat(x) * outer, y: center.y + CGFloat(y) * outer)
        }
        for case let point? in manual { taken.append(box(point, valueSize)) }

        // Where each value would like to sit.
        let preferred: [CGPoint] = values.indices.map { i in
            var p = values.count == 1 ? center : ringPoint(i, of: values.count, radius: outer * 0.42, turn: 0.5)
            let linked = links.compactMap { link -> CGPoint? in
                guard link.value == values[i], let loop = link.loopA, let j = loops.firstIndex(of: loop) else { return nil }
                return loopPoints[j]
            }
            if !linked.isEmpty {
                let tx = linked.map(\.x).reduce(0, +) / CGFloat(linked.count)
                let ty = linked.map(\.y).reduce(0, +) / CGFloat(linked.count)
                p = clamp(CGPoint(x: p.x + (tx - p.x) * 0.5, y: p.y + (ty - p.y) * 0.5), center: center, limit: outer * 0.6)
            }
            return p
        }

        // Spots to choose from: a fine grid inside the map.
        let limit = outer * 0.9
        let step: CGFloat = 7
        let reach = Int(limit / step)
        var spots: [CGPoint] = []
        for x in -reach...reach {
            for y in -reach...reach {
                let dx = CGFloat(x) * step, dy = CGFloat(y) * step
                if dx * dx + dy * dy <= limit * limit { spots.append(CGPoint(x: center.x + dx, y: center.y + dy)) }
            }
        }

        var points = preferred
        for i in values.indices {
            if let point = manual[i] {
                points[i] = point
                continue
            }
            var best = preferred[i]
            var bestOverlap = CGFloat.infinity
            var bestDistance = CGFloat.infinity
            for spot in spots {
                let rect = box(spot, valueSize)
                var overlap: CGFloat = 0
                for other in taken where other.intersects(rect) {
                    let shared = other.intersection(rect)
                    overlap += shared.width * shared.height
                }
                guard overlap <= bestOverlap else { continue }
                let distance = hypot(spot.x - preferred[i].x, spot.y - preferred[i].y)
                if overlap < bestOverlap || distance < bestDistance {
                    best = spot
                    bestOverlap = overlap
                    bestDistance = distance
                }
            }
            points[i] = best
            taken.append(box(best, valueSize))
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
