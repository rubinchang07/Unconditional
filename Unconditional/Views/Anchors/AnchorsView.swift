import SwiftUI
import SwiftData

/// Anchors: what stays true about you, whatever happens.
///
/// The page is a body of water. The top is the surface, bright and a little
/// restless. Scrolling down is going deeper: the color deepens, the stream
/// slows, and things get steadier. Wins sparkle near the surface, words to
/// come back to drift in the middle current, and your values rest on the
/// riverbed. The deeper you go, the steadier it gets.
struct AnchorsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage
    @Query(sort: \Win.createdAt, order: .reverse) private var wins: [Win]
    @Query(sort: \SavedReminder.createdAt, order: .reverse) private var reminders: [SavedReminder]
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]

    /// Where you are in the water.
    @State private var scroll = ScrollState()
    @State private var adding = false
    /// A new anchor falling from the surface to its layer.
    @State private var droppedAt: Date?
    /// A reminder rising as a bubble after pulling down at the surface.
    @State private var bubble: SavedReminder?
    @State private var pulled = false

    struct ScrollState: Equatable {
        var offset: CGFloat = 0
        var content: CGFloat = 1
        var viewport: CGFloat = 1
        /// 0 at the surface, 1 at the riverbed.
        var depth: Double {
            let travel = max(content - viewport, 1)
            return Double(min(max(offset / travel, 0), 1))
        }
    }

    /// How far in from the left the stream runs.
    static let streamX: CGFloat = 26

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    surface
                    winsLayer
                    wordsLayer
                    valuesLayer
                }
                .padding(.leading, Self.streamX + 22)
                .padding(.trailing, 20)
                .padding(.bottom, 60)
                .background(alignment: .topLeading) {
                    Stream(scroll: scroll, color: palette.colors[0])
                        .allowsHitTesting(false)
                }
            }
            .onScrollGeometryChange(for: ScrollState.self) { geometry in
                ScrollState(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                            content: geometry.contentSize.height,
                            viewport: geometry.containerSize.height)
            } action: { _, new in
                scroll = new
                surfacePull(new.offset)
            }
            .background { depthBackground.ignoresSafeArea() }
            .overlay(alignment: .top) { bubbleView }
            .overlay { fallingDrop }
            .navigationTitle("anchors")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add an anchor", systemImage: "plus") { adding = true }
                }
            }
            .sheet(isPresented: $adding) {
                AddAnchorSheet {
                    if !reduceMotion { droppedAt = .now }
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: pulled) { _, new in new }
        }
    }

    // MARK: - The water

    /// White at the surface, a faint wash of color further down.
    private var depthBackground: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            LinearGradient(colors: [palette.colors[0].opacity(0.04), palette.colors[0].opacity(0.16)],
                           startPoint: .top, endPoint: .bottom)
                .opacity(0.35 + 0.65 * scroll.depth)
        }
        .animation(.easeOut(duration: 0.4), value: scroll.depth)
    }

    private var surface: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The deeper you go, the steadier it gets.")
                .font(.system(.title3, design: .serif))
            Text("Pull down at the surface for something you wanted to remember.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Near the surface: wins

    private var winsLayer: some View {
        Layer(title: "you kept showing up", subtitle: "Small things count. So does trying.") {
            if wins.isEmpty {
                Text("Your wins will gather here.").foregroundStyle(.secondary)
            }
            ForEach(wins) { win in
                DropCard(color: palette.colors[2]) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(win.text)
                        if !win.meaning.isEmpty {
                            Text(win.meaning).font(.callout).foregroundStyle(.secondary)
                        }
                        Text(win.effortLabel.lowercased())
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .contextMenu {
                    Button("Remove", systemImage: "minus.circle") { withAnimation(.calm) { context.delete(win) } }
                }
            }
        }
    }

    // MARK: - The middle current: words to come back to

    private var wordsLayer: some View {
        Layer(title: "words to come back to", subtitle: "In your own words. Swipe through them one at a time.") {
            if reminders.isEmpty {
                Text("Things you'd want to hear when it's a lot. Rewritten perspectives from a thought reset land here too.")
                    .foregroundStyle(.secondary)
            } else {
                TabView {
                    ForEach(reminders) { reminder in
                        DropCard(color: palette.colors[0]) {
                            Text(reminder.text)
                                .font(.system(.title3, design: .serif))
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 30)
                        .contextMenu {
                            Button("Remove", systemImage: "minus.circle") { withAnimation(.calm) { context.delete(reminder) } }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .frame(height: 210)
            }
        }
    }

    // MARK: - The riverbed: values

    private var valuesLayer: some View {
        Layer(title: "what holds you", subtitle: "What you care about, on good days and hard ones.") {
            if values.isEmpty {
                Text("Add the values that feel like yours. They'll rest here, steady, whatever the day brings.")
                    .foregroundStyle(.secondary)
            } else {
                BubbleCluster(spacing: 14) {
                    ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                        NavigationLink {
                            ValueDetailView(value: value)
                        } label: {
                            VStack(spacing: 6) {
                                MiniOrb(color: palette.colors[index % 3], seed: Double(index) * 2.1)
                                    .frame(width: orbSize(value), height: orbSize(value))
                                Text(value.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .fixedSize()
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove", systemImage: "minus.circle") { withAnimation(.calm) { context.delete(value) } }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(alignment: .bottom) {
                    // A soft riverbed for them to rest on.
                    Ellipse()
                        .fill(palette.colors[0].opacity(0.12))
                        .frame(height: 50)
                        .blur(radius: 12)
                        .offset(y: 10)
                }
            }
        }
    }

    /// Bigger when you've lived it more lately, but never tiny.
    private func orbSize(_ value: PersonalValue) -> CGFloat {
        44 + CGFloat(value.livedLately) * 3
    }

    // MARK: - Pull at the surface for a bubble

    private func surfacePull(_ offset: CGFloat) {
        if offset < -90, !pulled, let reminder = reminders.randomElement() {
            pulled = true
            withAnimation(.spring(duration: 0.8)) { bubble = reminder }
            Task {
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.easeOut(duration: 0.8)) { bubble = nil }
            }
        } else if offset > -10, pulled {
            pulled = false
        }
    }

    @ViewBuilder
    private var bubbleView: some View {
        if let bubble {
            Text(bubble.text)
                .font(.system(.body, design: .serif))
                .multilineTextAlignment(.center)
                .padding(20)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(palette.colors[0].opacity(0.12))
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)
                .onTapGesture { withAnimation(.easeOut) { self.bubble = nil } }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.6)),
                                        removal: .opacity.combined(with: .offset(y: -40))))
        }
    }

    // MARK: - A new anchor falls in

    @ViewBuilder
    private var fallingDrop: some View {
        if let droppedAt {
            TimelineView(.animation) { timeline in
                let e = timeline.date.timeIntervalSince(droppedAt)
                GeometryReader { proxy in
                    let p = Gooey.ease(e / 1.4)
                    MiniOrb(color: palette.colors[1])
                        .frame(width: 34, height: 34)
                        .position(x: Self.streamX, y: 20 + (proxy.size.height - 60) * CGFloat(p))
                        .opacity(e > 1.4 ? max(0, 1 - (e - 1.4) / 0.5) : 1)
                }
            }
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(2))
                self.droppedAt = nil
            }
        }
    }
}

// MARK: - Pieces

/// A titled layer of the water.
private struct Layer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            content
        }
    }
}

/// A card that arrives as a drop: a small orb that lands and spreads open,
/// the way a drop becomes a little pool.
struct DropCard<Content: View>: View {
    let color: Color
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(padding: 16)
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.15, anchor: .topLeading)
            .overlay(alignment: .topLeading) {
                // The drop itself, fading as the card opens.
                MiniOrb(color: color)
                    .frame(width: 26, height: 26)
                    .offset(x: -6, y: landed ? 0 : -40)
                    .opacity(landed ? 0 : 1)
                    .allowsHitTesting(false)
            }
            .onAppear {
                guard !landed else { return }
                if reduceMotion { landed = true; return }
                withAnimation(.spring(duration: 0.7, bounce: 0.25)) { landed = true }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.35), trigger: landed) { _, new in new && !reduceMotion }
    }
}

/// The stream: a soft line of water down the left of the page, with drops
/// sliding along it. Scrolling pushes them along faster; deeper, it all slows.
private struct Stream: View {
    let scroll: AnchorsView.ScrollState
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // Only draw what's on screen, plus a little either side.
                let top = max(0, scroll.offset - 80)
                let bottom = min(size.height, scroll.offset + scroll.viewport + 80)
                guard bottom > top else { return }
                let calm = 1 - 0.6 * scroll.depth
                let x = AnchorsView.streamX

                func wiggle(_ y: CGFloat) -> CGFloat {
                    x + CGFloat(sin(Double(y) / 90 + t * 0.6) * 5 * calm)
                }

                var silhouette = ctx
                silhouette.opacity = 0.5
                silhouette.addFilter(.alphaThreshold(min: 0.5, color: color))
                silhouette.addFilter(.blur(radius: 5))
                silhouette.drawLayer { layer in
                    var line = Path()
                    line.move(to: CGPoint(x: wiggle(top), y: top))
                    var y = top
                    while y < bottom {
                        y += 8
                        line.addLine(to: CGPoint(x: wiggle(y), y: y))
                    }
                    layer.stroke(line, with: .color(.black), lineWidth: 5)

                    // Drops slide down; scrolling adds to their travel.
                    let spacing: CGFloat = 140
                    let travel = CGFloat(t * 26 * calm) + scroll.offset * 0.5
                    var dropY = top - top.truncatingRemainder(dividingBy: spacing) + travel.truncatingRemainder(dividingBy: spacing)
                    while dropY < bottom {
                        if dropY > top {
                            let r: CGFloat = 7 + CGFloat(sin(Double(dropY) * 0.07)) * 2
                            layer.fill(Circle().path(in: Gooey.rect(CGPoint(x: wiggle(dropY), y: dropY), r)), with: .color(.black))
                        }
                        dropY += spacing
                    }
                }
            }
        }
    }
}

// MARK: - Adding an anchor

/// One place to add any kind of anchor.
private struct AddAnchorSheet: View {
    enum Kind: String, CaseIterable, Identifiable {
        case win = "a win", words = "words", value = "a value"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var values: [PersonalValue]
    let onAdded: () -> Void

    @State private var kind: Kind = .win
    @State private var text = ""
    @State private var meaning = ""
    @State private var tried = false
    @State private var workedOut = false

    private var unusedValues: [String] {
        let taken = Set(values.map { $0.name.lowercased() })
        return PersonalValue.suggestions.filter { !taken.contains($0.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Add", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                switch kind {
                case .win:
                    Section {
                        TextField("What went right, even a little?", text: $text, axis: .vertical)
                        TextField("What does it say about you? (optional)", text: $meaning, axis: .vertical)
                        HStack(spacing: 10) {
                            WordChip(title: "I tried", isOn: $tried)
                            WordChip(title: "It worked out", isOn: $workedOut)
                        }
                    }
                case .words:
                    Section {
                        TextField("Something you'd want to hear when it's a lot", text: $text, axis: .vertical)
                    } footer: {
                        Text("For example: I can feel uncertain and still take one step.")
                    }
                case .value:
                    Section {
                        TextField("A value, in a word or two", text: $text)
                        TextField("What it looks like for you (optional)", text: $meaning, axis: .vertical)
                    }
                    if !unusedValues.isEmpty {
                        Section("Or pick one") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(unusedValues, id: \.self) { name in
                                    WordChip(title: name, isOn: Binding(get: { text == name }, set: { if $0 { text = name } }))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("add an anchor")
            .navigationBarTitleDisplayMode(.inline)
            .themedBackground()
            .paperList()
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func add() {
        let main = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .win:
            let effort: Double = tried && !workedOut ? 0.1 : (workedOut && !tried ? 0.9 : 0.5)
            context.insert(Win(text: main, meaning: extra, effortToOutcome: effort))
        case .words:
            context.insert(SavedReminder(text: main))
        case .value:
            context.insert(PersonalValue(name: main, meaning: extra))
        }
        try? context.save()
        dismiss()
        onAdded()
    }
}
