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
    /// The thread whose knot you tapped (or just tied), shown with its slider under the map.
    @State private var selectedLink: MapLink?
    /// A dotted guess you tapped, shown with why the app suggested it.
    @State private var selectedHint: Suggestion?
    /// Lean the map back for a 2.5D view, or keep it flat. Remembered.
    @AppStorage("mapTilted") private var tilted = true
    /// While you're pulling a thread or moving something, the map lies flat so it's easy to aim.
    @State private var handsOn = false
    @State private var spin = 0.0
    /// The turn cue shows until the first time you turn the map.
    @AppStorage("hasTurnedMap") private var hasTurnedMap = false

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
                    let visible = MapLayout.visibleLoops(loops, links: links)
                    // A guess always shows both its loops, even quieter ones.
                    let shown = showAllLoops ? loops : loops.filter { loop in
                        visible.contains(loop) || suggestions.contains { $0.a == loop || $0.b == loop }
                    }
                    MapWeb(loops: shown, values: values, links: links.filter(\.isConfirmed),
                           hints: suggestions.filter { shown.contains($0.a) && shown.contains($0.b) },
                           color: color(for:), onSelect: { selected = $0 },
                           tilt: tilted && !handsOn ? 0.8 : 0, spin: spin,
                           onHandsOn: { on in
                               withAnimation(.spring(duration: 0.45, bounce: 0.15)) { handsOn = on }
                           },
                           onSpin: { spin = $0 },
                           selectedLink: $selectedLink, selectedHint: $selectedHint)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(6)
                        .background { SpaceBackdrop(spin: spin) }
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(alignment: .topTrailing) { mapControls }
                        .overlay(alignment: .bottom) {
                            // A wordless hint that the map turns, until the first time you turn it.
                            if tilted && !hasTurnedMap { TurnCue().padding(.bottom, 10).allowsHitTesting(false) }
                        }
                        .onChange(of: spin) { _, _ in
                            if !hasTurnedMap { withAnimation(.calm) { hasTurnedMap = true } }
                        }

                    if let link = selectedLink, link.isConfirmed {
                        threadCard(link)
                    } else if let hint = selectedHint {
                        hintCard(hint)
                    }

                    // Quieter loops are one tap away, so the map never gets crowded.
                    if loops.count > MapLayout.loopLimit, shown.count < loops.count || showAllLoops {
                        let hidden = loops.count - shown.count
                        Button(showAllLoops ? "show fewer loops" : "+\(hidden) quieter \(hidden == 1 ? "loop" : "loops")") {
                            withAnimation(.calm) { showAllLoops.toggle() }
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Two quiet icons in the map's corner: flat or leaning back, and (once you've
    /// moved a value) putting values back where the map placed them.
    private var mapControls: some View {
        HStack(spacing: 8) {
            if values.contains(where: { $0.mapX != nil }) {
                Button {
                    withAnimation(.calm) {
                        for value in values { value.mapX = nil; value.mapY = nil }
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Put values back where the map placed them")
                .transition(.opacity)
            }
            Button {
                withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                    tilted.toggle()
                    if !tilted { spin = 0 }
                }
            } label: {
                Image(systemName: tilted ? "view.2d" : "view.3d")
            }
            .accessibilityLabel(tilted ? "Lie flat" : "Lean back")
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .buttonStyle(SpaceIconStyle())
        .padding(10)
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

    /// Under the map: how connected a thread feels, as a slider, with untie beside it.
    private func threadCard(_ link: MapLink) -> some View {
        let a = link.loopA?.name ?? ""
        let b = link.loopB?.name ?? link.value?.name ?? ""
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(a) and \(b)")
                .font(.system(.headline, design: .serif))
            RatingSlider(title: "How connected", value: Binding(get: { link.strength }, set: { link.strength = $0 }),
                         range: 0.05...1, step: 0.05,
                         lowLabel: "a little", highLabel: "very", valueText: MapLink.strengthLabel)
            HStack {
                Button("Untie") {
                    withAnimation(.calm) {
                        selectedLink = nil
                        if link.value != nil { context.delete(link) } else { link.status = "dismissed" }
                    }
                }
                .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { withAnimation(.calm) { selectedLink = nil } }
                    .buttonStyle(.paper)
            }
        }
        .paperCard()
        .transition(.opacity.combined(with: .offset(y: 8)))
    }

    /// Under the map: why the app guessed these two, and your answer.
    private func hintCard(_ hint: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(hint.a.name) and \(hint.b.name) showed up on the same day \(hint.days) times. Do they feel connected?")
                .font(.callout)
            Text("Trace the dotted thread from one to the other to tie them, or answer here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Not really") {
                    withAnimation(.calm) {
                        selectedHint = nil
                        add(hint, strength: 0, status: "dismissed")
                    }
                }
                .foregroundStyle(.secondary)
                Spacer()
                Button("Connect them") {
                    withAnimation(.calm) {
                        selectedHint = nil
                        selectedLink = add(hint, strength: 0.5)
                    }
                }
                .buttonStyle(.paper)
            }
        }
        .paperCard()
        .transition(.opacity.combined(with: .offset(y: 8)))
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

    @discardableResult
    private func add(_ suggestion: Suggestion, strength: Double, status: String = "confirmed") -> MapLink {
        let link = MapLink()
        context.insert(link)
        link.loopA = suggestion.a
        link.loopB = suggestion.b
        link.strength = strength
        link.status = status
        return link
    }
}

// MARK: - The web

/// Something on the map a thread can tie to.
enum MapNode: Equatable {
    case loop(Loop)
    case value(PersonalValue)

    var id: PersistentIdentifier {
        switch self {
        case .loop(let loop): loop.persistentModelID
        case .value(let value): value.persistentModelID
        }
    }
}

/// Values sit in the middle, loops around the outside. Threads are links you
/// tied yourself, thicker when they feel stronger. Dotted threads are the app's
/// guesses, waiting for you to trace them or pull them away.
///
/// Everything here is touch: pull a thread out of a loop and drop it on another
/// loop or a value to tie it; tap a knot to say how connected; pull a knot off
/// its thread to untie it.
private struct MapWeb: View, Animatable {
    @Environment(\.modelContext) private var context
    let loops: [Loop]
    let values: [PersonalValue]
    let links: [MapLink]
    let hints: [MapView.Suggestion]
    let color: (Loop) -> Color
    let onSelect: (Loop) -> Void
    /// How far the map leans back, in radians: 0 is flat, about 0.8 is like a tabletop.
    var tilt: Double = 0
    /// How far the map has been turned, in radians.
    var spin: Double = 0
    /// Lets SwiftUI ease tilt and spin smoothly, redrawing every frame in between.
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(tilt, spin) }
        set { tilt = newValue.first; spin = newValue.second }
    }
    /// True while a finger is working on something (a thread, a knot, a value), so the
    /// map can lie flat and hold still; false when it lets go.
    var onHandsOn: (Bool) -> Void = { _ in }
    /// Turning the map: called with the new angle while you drag on empty space.
    var onSpin: (Double) -> Void = { _ in }
    /// The thread whose knot you tapped, or just tied. Its slider shows under the map.
    @Binding var selectedLink: MapLink?
    @Binding var selectedHint: MapView.Suggestion?

    /// A value being dragged, and how far it has moved so far.
    @State private var dragging: (id: PersistentIdentifier, offset: CGSize)?
    /// The loop or value you tapped. Its connections stay lit and the rest fades back.
    @State private var focus: PersistentIdentifier?
    /// Where the map placed values when a drag began. Reused for every frame of the
    /// drag, so moving one value doesn't redo the whole layout 60 times a second.
    @State private var frozenLayout: [CGPoint]?
    /// A thread you're pulling out of a loop, and where your finger is.
    @State private var pulling: (from: Loop, to: CGPoint)?
    /// What the loose end is over right now, so it can light up before you let go.
    @State private var hovering: MapNode?
    /// A knot (or a hint's middle) being pulled, and how far.
    @State private var tugging: (id: String, offset: CGSize)?
    /// The node that just caught a thread, for a small bounce.
    @State private var caught: PersistentIdentifier?
    @State private var tiedCount = 0
    @State private var untiedCount = 0
    /// The angle when a turn began.
    @State private var spinStart: Double?
    /// The value layout, worked out only when something it depends on changes,
    /// not on every frame of a turn or a tilt.
    @State private var cache = LayoutCache()

    /// How far a knot has to be pulled before the thread lets go.
    private let snapDistance: CGFloat = 70
    /// How close the loose end has to be to catch on something.
    private let catchDistance: CGFloat = 38

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 46
            let auto = frozenLayout.flatMap { $0.count == values.count ? $0 : nil }
                ?? cache.points(for: layoutKey(size)) {
                    MapLayout.spread(values: values, loops: loops, links: links, center: center, outer: outer)
                }
            let projector = MapProjector(center: center, outer: outer, tilt: tilt, spin: spin)
            // Everything is placed on a flat plane first, then seen at an angle.
            let planePositions = values.indices.map { place(values[$0], auto: auto[$0], center: center, outer: outer, projector: projector) }
            let planeLoops = loops.indices.map { point($0, of: loops.count, radius: outer, center: center) }
            let positions = planePositions.map(projector.project)
            let loopSpots = planeLoops.map(projector.project)
            let spot: (MapNode) -> CGPoint? = { node in
                switch node {
                case .loop(let loop): loops.firstIndex(of: loop).map { loopSpots[$0] }
                case .value(let value): values.firstIndex(of: value).map { positions[$0] }
                }
            }

            ZStack {
                Canvas { ctx, _ in
                    // Faint guide rings, like pencil on paper, seen at the same angle as everything else.
                    for share in [1.0, 0.55] {
                        var ring = Path()
                        for i in 0...72 {
                            let angle = Double(i) / 72 * 2 * .pi
                            let p = projector.project(CGPoint(x: center.x + outer * share * cos(angle),
                                                              y: center.y + outer * share * sin(angle)))
                            if i == 0 { ring.move(to: p) } else { ring.addLine(to: p) }
                        }
                        ctx.stroke(ring, with: .color(.white.opacity(share == 1 ? 0.16 : 0.09)),
                                   style: StrokeStyle(lineWidth: 0.8))
                    }

                    // The app's guesses: dotted and faint. Brighter while you pull from one of their loops.
                    for hint in hints {
                        guard let s = spot(.loop(hint.a)), let e = spot(.loop(hint.b)) else { continue }
                        let ends = [hint.a, hint.b]
                        let live = pulling.map { ends.contains($0.from) } ?? false
                        let tug = tugging?.id == hint.id ? tugging?.offset : nil
                        let path = thread(from: s, to: e, center: center, tug: tug)
                        ctx.stroke(path, with: .color(.white.opacity(live ? 0.6 : 0.28)),
                                   style: StrokeStyle(lineWidth: live ? 2.5 : 1.5, lineCap: .round, dash: [2, 6]))
                    }

                    // Threads you tied.
                    for link in links {
                        guard let a = link.loopA, let s = spot(.loop(a)) else { continue }
                        let other: MapNode? = link.loopB.map { MapNode.loop($0) } ?? link.value.map { MapNode.value($0) }
                        guard let other, let e = spot(other) else { continue }
                        let tug = tugging?.id == key(link) ? tugging?.offset : nil
                        let stretch = tug.map { min(hypot($0.width, $0.height) / snapDistance, 1) } ?? 0
                        let faded = focus.map { !involves(link, $0) } ?? false
                        let width = (1 + link.strength * 5) * (1 - stretch * 0.7)
                        let shade = color(a).opacity((0.25 + link.strength * 0.45) * (faded ? 0.12 : 1))
                        let curve = thread(from: s, to: e, center: center, tug: tug, bow: link.loopB != nil)
                        // A soft glow under each thread, like light between planets.
                        ctx.drawLayer { glow in
                            glow.addFilter(.blur(radius: 4))
                            glow.stroke(curve, with: .color(shade.opacity(0.7)), style: StrokeStyle(lineWidth: width + 4, lineCap: .round))
                        }
                        ctx.stroke(curve, with: .color(shade), style: StrokeStyle(lineWidth: width, lineCap: .round))
                    }

                    // The thread you're pulling: a soft, gooey strand that swells at your fingertip.
                    if let pulling, let s = spot(.loop(pulling.from)) {
                        let end = hovering.flatMap(spot) ?? pulling.to
                        let length = hypot(end.x - s.x, end.y - s.y)
                        let count = max(2, Int(length / 7))
                        let blobs = (0...count).map { i -> GooeyBlob in
                            let t = CGFloat(i) / CGFloat(count)
                            let p = CGPoint(x: s.x + (end.x - s.x) * t, y: s.y + (end.y - s.y) * t)
                            // Thin in the middle, rounder at both ends, like something stretched.
                            let r = 4 + 4 * pow(abs(t - 0.5) * 2, 3) + (t > 0.9 ? 4 : 0)
                            return GooeyBlob(center: p, radius: r, color: color(pulling.from))
                        }
                        Gooey.draw(blobs, in: ctx, base: color(pulling.from), blur: 6)
                    }
                }
                // Tapping empty space lets everything come back.
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.calm) {
                        focus = nil
                        selectedLink = nil
                        selectedHint = nil
                    }
                }
                // Sliding sideways on empty space turns the map, like spinning a model of the planets.
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { drag in
                            let start = spinStart ?? spin
                            if spinStart == nil { spinStart = start }
                            onSpin(start + Double(drag.translation.width) / 140)
                        }
                        .onEnded { _ in spinStart = nil }
                )

                // Hints: a small dot in the middle to tap (why?) or pull away (not really).
                ForEach(hints, id: \.id) { hint in
                    if let s = spot(.loop(hint.a)), let e = spot(.loop(hint.b)) {
                        let mid = midpoint(from: s, to: e, center: center)
                        let tug = tugging?.id == hint.id ? tugging?.offset ?? .zero : .zero
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.08), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 3])))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .opacity(tugOpacity(tug))
                            .position(x: mid.x + tug.width, y: mid.y + tug.height)
                            .gesture(tugGesture(id: hint.id) {
                                withAnimation(.calm) { selectedHint = hint; selectedLink = nil }
                            } onSnap: {
                                dismiss(hint)
                            })
                            .accessibilityLabel("A guess: \(hint.a.name) and \(hint.b.name)")
                            .accessibilityHint("Shows why, and lets you connect them or not")
                            .accessibilityAction { selectedHint = hint }
                    }
                }

                // Knots: tap to say how connected, pull off to untie.
                ForEach(links, id: \.persistentModelID) { link in
                    if let a = link.loopA, let s = spot(.loop(a)),
                       let e = (link.loopB.map { MapNode.loop($0) } ?? link.value.map { MapNode.value($0) }).flatMap(spot) {
                        let mid = midpoint(from: s, to: e, center: center, bow: link.loopB != nil)
                        let tug = tugging?.id == key(link) ? tugging?.offset ?? .zero : .zero
                        let faded = focus.map { !involves(link, $0) } ?? false
                        Circle()
                            .fill(color(a))
                            .frame(width: selectedLink == link ? 14 : 9, height: selectedLink == link ? 14 : 9)
                            .shadow(color: color(a).opacity(0.9), radius: 5)
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                            .opacity(faded ? 0.2 : tugOpacity(tug))
                            .position(x: mid.x + tug.width, y: mid.y + tug.height)
                            .gesture(tugGesture(id: key(link)) {
                                withAnimation(.calm) { selectedLink = link; selectedHint = nil }
                            } onSnap: {
                                untie(link)
                            })
                            .accessibilityLabel(linkName(link))
                            .accessibilityValue(MapLink.strengthLabel(link.strength))
                            .accessibilityHint("Shows how connected, or lets you untie it")
                            .accessibilityAction { selectedLink = link }
                    }
                }

                ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                    let isDragging = dragging?.id == value.persistentModelID
                    let isTarget = hovering == .value(value)
                    let depth = projector.scale(at: planePositions[index])
                    // The capsule hugs the word, however long or short it is.
                    Text(MapLayout.shortName(value.name))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(isDragging || isTarget ? 0.2 : 0.1), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(isDragging || isTarget ? 0.7 : 0.25), lineWidth: isTarget ? 1.5 : 0.8))
                        // Only the lift is animated. Animating the whole label made its
                        // position spring toward your finger, so it trailed behind.
                        .animation(.spring(duration: 0.3, bounce: 0.5)) {
                            $0.scaleEffect(isDragging || isTarget ? 1.12 : caught == value.persistentModelID ? 1.2 : 1)
                                .shadow(color: .black.opacity(isDragging ? 0.15 : 0), radius: 6, y: 3)
                        }
                        // Nearer things are a little bigger and clearer; farther ones recede.
                        .scaleEffect(depth)
                        .opacity((isDragging || isTarget ? 1 : presence(value.persistentModelID)) * projector.clarity(depth))
                        .position(positions[index])
                        // One gesture for both: a touch that barely moves is a tap (focus),
                        // anything more is a drag.
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("map"))
                                .onChanged { drag in
                                    let moved = hypot(drag.translation.width, drag.translation.height)
                                    guard moved > 4 || dragging != nil else { return }
                                    if frozenLayout == nil {
                                        frozenLayout = auto
                                        onHandsOn(true)
                                    }
                                    dragging = (value.persistentModelID, drag.translation)
                                }
                                .onEnded { drag in
                                    defer { dragging = nil; frozenLayout = nil }
                                    guard dragging != nil else {
                                        toggleFocus(value.persistentModelID)
                                        return
                                    }
                                    onHandsOn(false)
                                    let p = place(value, auto: auto[index], center: center, outer: outer,
                                                  projector: projector, includingDrag: false)
                                    let delta = projector.planeDelta(drag.translation)
                                    let end = CGPoint(x: p.x + delta.width, y: p.y + delta.height)
                                    let spot = MapLayout.clamp(end, center: center, limit: outer * MapLayout.dragLimit)
                                    value.mapX = Double((spot.x - center.x) / outer)
                                    value.mapY = Double((spot.y - center.y) / outer)
                                }
                        )
                        .zIndex(isDragging ? 10 : Double(depth))
                        .sensoryFeedback(.selection, trigger: isDragging)
                        .accessibilityAddTraits(focus == value.persistentModelID ? [.isButton, .isSelected] : .isButton)
                        .accessibilityHint("Tap to light up its connections. Drag to move it on your map.")
                        .accessibilityAction { toggleFocus(value.persistentModelID) }
                }

                ForEach(Array(loops.enumerated()), id: \.element.id) { index, loop in
                    let isTarget = hovering == .loop(loop)
                    let isSource = pulling?.from == loop
                    let depth = projector.scale(at: planeLoops[index])
                    VStack(spacing: 4) {
                        // Loops are rings here too, matching Patterns.
                        // Loops are rings here too, like planets with rings, glowing softly.
                        MiniRing(color: color(loop))
                            .frame(width: MapLayout.dotSize(loop) + 6, height: MapLayout.dotSize(loop) + 6)
                            .shadow(color: color(loop).opacity(0.8), radius: 8)
                            .animation(.spring(duration: 0.3, bounce: 0.5)) {
                                $0.scaleEffect(isTarget || isSource ? 1.2 : caught == loop.persistentModelID ? 1.3 : 1)
                            }
                        Text(loop.name)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 84)
                    }
                    .contentShape(Rectangle())
                    .scaleEffect(depth)
                    .opacity((isTarget || isSource ? 1 : presence(loop.persistentModelID)) * projector.clarity(depth))
                    .position(loopSpots[index])
                    .zIndex(Double(depth))
                    // Tap: light up its connections (a second tap opens it).
                    // Pull: a thread comes out, to drop on another loop or a value.
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("map"))
                            .onChanged { drag in
                                let moved = hypot(drag.translation.width, drag.translation.height)
                                guard moved > 8 || pulling != nil else { return }
                                if pulling == nil { onHandsOn(true) }
                                pulling = (loop, drag.location)
                                let target = nearest(to: drag.location, excluding: loop, loopSpots: loopSpots, positions: positions)
                                if target != hovering { hovering = target }
                            }
                            .onEnded { _ in
                                defer { pulling = nil; hovering = nil }
                                guard pulling != nil else {
                                    if focus == loop.persistentModelID {
                                        onSelect(loop)
                                    } else {
                                        toggleFocus(loop.persistentModelID)
                                    }
                                    return
                                }
                                onHandsOn(false)
                                if let hovering { tie(loop, to: hovering) }
                            }
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("\(loop.name), \(loop.entries.count) entries")
                    .accessibilityAddTraits(focus == loop.persistentModelID ? .isSelected : [])
                    .accessibilityHint("Lights up its connections. Pull to tie a thread to another loop or a value.")
                    .accessibilityAction { toggleFocus(loop.persistentModelID) }
                    .accessibilityAction(named: "Open") { onSelect(loop) }
                    .accessibilityActions {
                        ForEach(loops.filter { $0 != loop }) { other in
                            Button("Tie to \(other.name)") { tie(loop, to: .loop(other)) }
                        }
                        ForEach(values) { value in
                            Button("Tie to \(value.name)") { tie(loop, to: .value(value)) }
                        }
                    }
                }
            }
            .coordinateSpace(.named("map"))
            .sensoryFeedback(.selection, trigger: hovering)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: tiedCount)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: untiedCount)
        }
    }

    // MARK: Tying and untying

    /// Ties a thread from a loop to another loop or a value. If you'd tied (or turned
    /// down) these two before, that same link comes back rather than a second one.
    private func tie(_ loop: Loop, to node: MapNode) {
        let existing: MapLink?
        switch node {
        case .loop(let other):
            guard other != loop else { return }
            existing = allLinks.first { $0.value == nil && $0.joins(loop, other) }
        case .value(let value):
            existing = allLinks.first { $0.loopA == loop && $0.value == value }
        }
        let link: MapLink
        if let existing {
            link = existing
            if !link.isConfirmed { link.strength = 0.5 }
        } else {
            link = MapLink()
            context.insert(link)
            link.loopA = loop
            switch node {
            case .loop(let other): link.loopB = other
            case .value(let value): link.value = value
            }
            link.strength = 0.5
        }
        link.status = "confirmed"
        tiedCount += 1
        caught = node.id
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            caught = nil
        }
        // Straight away: how connected? A thread is never just on or off.
        withAnimation(.calm) {
            selectedHint = nil
            selectedLink = link
        }
    }

    private func untie(_ link: MapLink) {
        untiedCount += 1
        withAnimation(.calm) {
            if selectedLink == link { selectedLink = nil }
            if link.value != nil {
                context.delete(link)
            } else {
                // Kept as "turned down", so the app doesn't suggest these two again.
                link.status = "dismissed"
            }
        }
    }

    private func dismiss(_ hint: MapView.Suggestion) {
        untiedCount += 1
        withAnimation(.calm) {
            if selectedHint?.id == hint.id { selectedHint = nil }
            let link = MapLink()
            context.insert(link)
            link.loopA = hint.a
            link.loopB = hint.b
            link.strength = 0
            link.status = "dismissed"
        }
    }

    /// Every link, including turned-down ones, so tying never makes a duplicate.
    private var allLinks: [MapLink] {
        (try? context.fetch(FetchDescriptor<MapLink>())) ?? links
    }

    /// A tap (barely moving) or a tug (pulling away). Pull past `snapDistance` and let
    /// go to snap; anything less springs back.
    private func tugGesture(id: String, onTap: @escaping () -> Void, onSnap: @escaping () -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let moved = hypot(drag.translation.width, drag.translation.height)
                guard moved > 6 || tugging != nil else { return }
                if tugging == nil { onHandsOn(true) }
                tugging = (id, drag.translation)
            }
            .onEnded { drag in
                guard tugging != nil else {
                    onTap()
                    return
                }
                onHandsOn(false)
                let moved = hypot(drag.translation.width, drag.translation.height)
                if moved > snapDistance {
                    tugging = nil
                    onSnap()
                } else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.5)) { tugging = nil }
                }
            }
    }

    /// A knot fades as you pull it, so you can feel it about to let go.
    private func tugOpacity(_ tug: CGSize) -> Double {
        1 - 0.6 * min(hypot(tug.width, tug.height) / snapDistance, 1)
    }

    private func key(_ link: MapLink) -> String { "\(link.persistentModelID.hashValue)" }

    private func linkName(_ link: MapLink) -> String {
        let a = link.loopA?.name ?? ""
        let b = link.loopB?.name ?? link.value?.name ?? ""
        return "Thread between \(a) and \(b)"
    }

    /// The closest loop or value to the loose end, if it's close enough to catch.
    private func nearest(to point: CGPoint, excluding source: Loop, loopSpots: [CGPoint], positions: [CGPoint]) -> MapNode? {
        var best: (node: MapNode, distance: CGFloat)?
        for (i, loop) in loops.enumerated() where loop != source {
            let d = hypot(loopSpots[i].x - point.x, loopSpots[i].y - point.y)
            if d < catchDistance, d < (best?.distance ?? .infinity) { best = (.loop(loop), d) }
        }
        for (i, value) in values.enumerated() {
            let d = hypot(positions[i].x - point.x, positions[i].y - point.y)
            if d < catchDistance, d < (best?.distance ?? .infinity) { best = (.value(value), d) }
        }
        return best?.node
    }

    // MARK: Drawing threads

    /// The bend point of a thread. Loop to loop bows toward the middle; loop to value is straight.
    private func control(from s: CGPoint, to e: CGPoint, center: CGPoint, bow: Bool) -> CGPoint {
        let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
        return bow ? CGPoint(x: (mid.x + center.x) / 2, y: (mid.y + center.y) / 2) : mid
    }

    /// The point halfway along the thread, where its knot sits.
    private func midpoint(from s: CGPoint, to e: CGPoint, center: CGPoint, bow: Bool = true) -> CGPoint {
        let c = control(from: s, to: e, center: center, bow: bow)
        return CGPoint(x: 0.25 * s.x + 0.5 * c.x + 0.25 * e.x, y: 0.25 * s.y + 0.5 * c.y + 0.25 * e.y)
    }

    /// A thread as a curve. When its knot is being pulled, the curve bends to follow it.
    private func thread(from s: CGPoint, to e: CGPoint, center: CGPoint, tug: CGSize? = nil, bow: Bool = true) -> Path {
        var c = control(from: s, to: e, center: center, bow: bow)
        if let tug {
            // Move the bend so the curve's halfway point lands on the pulled knot.
            c.x += tug.width * 2
            c.y += tug.height * 2
        }
        var path = Path()
        path.move(to: s)
        path.addQuadCurve(to: e, control: c)
        return path
    }

    // MARK: Focus

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

    /// Where a value is drawn: where you put it, or where the map placed it,
    /// plus any drag in progress.
    private func place(_ value: PersonalValue, auto: CGPoint, center: CGPoint, outer: CGFloat,
                       projector: MapProjector, includingDrag: Bool = true) -> CGPoint {
        var p = auto
        if let x = value.mapX, let y = value.mapY {
            p = CGPoint(x: center.x + CGFloat(x) * outer, y: center.y + CGFloat(y) * outer)
        }
        if includingDrag, let dragging, dragging.id == value.persistentModelID {
            // The finger moves on screen; turn that back into a move on the (possibly turned) map.
            let delta = projector.planeDelta(dragging.offset)
            p.x += delta.width
            p.y += delta.height
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

    /// Everything the value layout depends on. When this text is unchanged, the last layout is reused.
    private func layoutKey(_ size: CGSize) -> String {
        var key = "\(Int(size.width))x\(Int(size.height))"
        for value in values {
            key += "|v\(value.persistentModelID.hashValue):\(value.mapX ?? -9):\(value.mapY ?? -9):\(value.name)"
        }
        for loop in loops { key += "|l\(loop.persistentModelID.hashValue):\(loop.name):\(loop.entries.count)" }
        for link in links { key += "|k\(link.persistentModelID.hashValue):\(link.strength)" }
        return key
    }
}

/// Remembers the last value layout. A class, so updating it while drawing
/// doesn't count as a change that would redraw the view again.
final class LayoutCache {
    private var key = ""
    private var points: [CGPoint] = []

    func points(for key: String, make: () -> [CGPoint]) -> [CGPoint] {
        if key != self.key {
            points = make()
            self.key = key
        }
        return points
    }
}

// MARK: - Seeing the map at an angle

/// Turns the flat map into a 2.5D view: turned by `spin`, then leaned back by `tilt`
/// with a little perspective, so the far side is smaller and fainter. Labels are
/// only moved and scaled, never slanted, so they always read upright.
struct MapProjector {
    let center: CGPoint
    let outer: CGFloat
    let tilt: Double
    let spin: Double

    /// How far away the viewer is. Larger is a gentler perspective.
    private var focal: CGFloat { max(outer, 1) * 3.2 }

    private func turned(_ p: CGPoint) -> CGPoint {
        let x = p.x - center.x, y = p.y - center.y
        return CGPoint(x: x * cos(spin) - y * sin(spin), y: x * sin(spin) + y * cos(spin))
    }

    /// Bigger than 1 for the near side, smaller for the far side. Exactly 1 when flat.
    func scale(at p: CGPoint) -> CGFloat {
        let depth = -turned(p).y * sin(tilt) // the top of the map leans away
        return focal / max(focal + depth, 1)
    }

    /// Where a point on the map lands on screen.
    func project(_ p: CGPoint) -> CGPoint {
        let r = turned(p)
        let s = scale(at: p)
        return CGPoint(x: center.x + r.x * s, y: center.y + r.y * cos(tilt) * s)
    }

    /// A move on screen, turned back into a move on the map (close enough for dragging).
    func planeDelta(_ move: CGSize) -> CGSize {
        let x = move.width, y = move.height / max(cos(tilt), 0.3)
        return CGSize(width: x * cos(spin) + y * sin(spin), height: -x * sin(spin) + y * cos(spin))
    }

    /// Far things fade a little, like distance.
    func clarity(_ scale: CGFloat) -> Double {
        min(1, max(0.45, 1 - Double(1 - scale) * 2.2))
    }
}

// MARK: - Placing values

/// Spreads values out so their labels don't overlap, and nudges each one
/// toward the loops it's linked to so lines stay short and cross less.
enum MapLayout {
    /// Room a value label needs around it.
    static let labelHeight: CGFloat = 30
    /// Longer names are shortened on the map (the full name is in the value itself).
    static let nameLimit = 18

    static func shortName(_ name: String) -> String {
        name.count > nameLimit ? String(name.prefix(nameLimit - 1)) + "…" : name
    }

    /// About how much room a value's label takes: its word, plus the capsule around it
    /// and a little breathing space.
    static func valueSize(_ name: String) -> CGSize {
        CGSize(width: CGFloat(shortName(name).count) * 6.2 + 30, height: labelHeight)
    }
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
        // Before the map has a real size (its first layout pass can be zero wide),
        // there's no room to place anything yet, so everything waits in the middle.
        guard outer > 1 else { return values.map { _ in center } }

        func ringPoint(_ i: Int, of count: Int, radius: CGFloat, turn: Double = 0) -> CGPoint {
            let angle = -Double.pi / 2 + 2 * Double.pi * (Double(i) + turn) / Double(count)
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        func box(_ point: CGPoint, _ size: CGSize) -> CGRect {
            CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        }

        let loopPoints = loops.indices.map { ringPoint($0, of: loops.count, radius: outer) }
        var taken: [CGRect] = loops.indices.map { box(loopPoints[$0], loopBox(loops[$0])) }

        // Values you've placed by hand stay put, and the rest keep clear of them.
        let manual: [CGPoint?] = values.map { value in
            guard let x = value.mapX, let y = value.mapY else { return nil }
            return CGPoint(x: center.x + CGFloat(x) * outer, y: center.y + CGFloat(y) * outer)
        }
        for (i, point) in manual.enumerated() {
            if let point { taken.append(box(point, valueSize(values[i].name))) }
        }

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
        let reach = max(0, Int(limit / step))
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
                let rect = box(spot, valueSize(values[i].name))
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
            taken.append(box(best, valueSize(values[i].name)))
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
