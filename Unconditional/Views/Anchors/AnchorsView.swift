import SwiftUI
import SwiftData
import PhotosUI

/// Anchors: what stays true about you, whatever happens.
///
/// The page is a body of water. The top is the surface, bright and a little
/// restless. Scrolling down is going deeper: the color deepens, the stream
/// slows, and things get steadier. Wins and things that made you laugh
/// sparkle near the surface, words to
/// come back to drift in the middle current, and your values rest on the
/// riverbed. The deeper you go, the steadier it gets.
struct AnchorsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage
    /// Until you first long-press a win, a small hand on the first one shows you can.
    @AppStorage("hasHeldWin") private var hasHeldWin = false
    @Query(sort: \Win.createdAt, order: .reverse) private var wins: [Win]
    @Query(sort: \SavedReminder.createdAt, order: .reverse) private var reminders: [SavedReminder]
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]
    @Query(sort: \GroundingPhoto.createdAt) private var photos: [GroundingPhoto]
    @Query(sort: \Laugh.createdAt, order: .reverse) private var laughs: [Laugh]
    /// The photo opened up close.
    @State private var openPhoto: GroundingPhoto?

    /// Where you are in the water.
    @State private var scroll = ScrollState()
    @State private var adding = false
    /// A new anchor falling from the surface to its layer.
    @State private var droppedAt: Date?
    /// Where the falls land, in screen coordinates, so the water stops there.
    @State private var splashY: CGFloat = .infinity

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
                    laughsLayer
                    wordsLayer
                    valuesLayer
                        .padding(.vertical, 24)
                        .padding(.trailing, 16)
                        .background {
                            // The bed reaches under the waterfall, so the falls land in it.
                            Riverbed(color: palette.colors[0])
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.frame(in: .global).minY + Riverbed.fadeIn + 6
                                } action: { splashY = $0 }
                                .padding(.leading, -(Self.streamX + 22))
                                .padding(.trailing, -20)
                                .padding(.top, -Riverbed.fadeIn)
                                // Reaches well past the end of the page, so the sand
                                // fills the screen to the very bottom, even when you
                                // bounce past the end.
                                .padding(.bottom, -600)
                        }
                }
                .padding(.leading, Self.streamX + 22)
                .padding(.trailing, 20)
                .padding(.bottom, 60)
            }
            .onScrollGeometryChange(for: ScrollState.self) { geometry in
                ScrollState(offset: geometry.contentOffset.y + geometry.contentInsets.top,
                            content: geometry.contentSize.height,
                            viewport: geometry.containerSize.height)
            } action: { _, new in
                scroll = new
            }
            .background {
                ZStack(alignment: .topLeading) {
                    depthBackground
                    // The falls stay fixed on screen while the page scrolls over them,
                    // so scrolling never speeds the water up. Only depth slows it.
                    GeometryReader { proxy in
                        // The water stops where it lands in the riverbed.
                        Stream(depth: scroll.depth, color: palette.colors[0],
                               stopAt: splashY - proxy.frame(in: .global).minY)
                    }
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
            .overlay { fallingDrop }
            .navigationTitle("anchors")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add an anchor", systemImage: "plus") { adding = true }
                }
            }
            .sheet(item: $openPhoto) { photo in
                PhotoCloseUp(photo: photo, glow: palette.colors[0])
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $adding) {
                AddAnchorSheet {
                    if !reduceMotion { droppedAt = .now }
                }
            }
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
        }
        .padding(.top, 8)
    }

    // MARK: - Near the surface: wins

    private var winsLayer: some View {
        let split = Win.split(wins)
        return Layer(title: "you kept showing up", subtitle: "Small things count. So does trying.") {
            if wins.isEmpty {
                Text("Your wins will gather here.").foregroundStyle(.secondary)
            }
            ForEach(split.surface) { win in
                DropCard(color: palette.colors[2]) {
                    WinContent(win: win)
                }
                // Once, on the first win: a small hand shows that wins can be held.
                .overlay(alignment: .trailing) {
                    if !hasHeldWin && win == split.surface.first {
                        HoldCue(color: palette.colors[2], size: 28)
                            .padding(.trailing, 8)
                            .allowsHitTesting(false)
                    }
                }
                .contextMenu { WinMenu(win: win) }
            }
            // After about two weeks, wins settle here instead of crowding the top.
            if !split.settled.isEmpty {
                NavigationLink {
                    KeptWinsView()
                } label: {
                    KeptStone(count: split.settled.count, color: palette.colors[2])
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Also near the surface: things that made you laugh

    /// Light things float. A row of slightly tilted cards, like notes stuck to a fridge.
    @ViewBuilder
    private var laughsLayer: some View {
        if !laughs.isEmpty {
            Layer(title: "things that made you laugh", subtitle: "") {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(laughs.enumerated()), id: \.element.id) { index, laugh in
                            DropCard(color: palette.colors[2]) {
                                LaughCard(laugh: laugh)
                            }
                            .frame(width: 230)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.5 : 1.2))
                            .contextMenu {
                                Button("Remove", systemImage: "minus.circle") { withAnimation(.calm) { context.delete(laugh) } }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - The middle current: words to come back to

    private var wordsLayer: some View {
        Layer(title: "words to come back to", subtitle: "In your own words. Swipe through them one at a time.") {
            if reminders.isEmpty {
                Text("Things you'd want to hear when it's a lot.")
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
        Layer(title: "what holds you", subtitle: "What you care about, on good days and hard ones. The falls land here.") {
            if !photos.isEmpty { photoRow }
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
                .padding(.top, 44)
                .padding(.bottom, 56)
            }
        }
    }

    /// Grounding photos, as stickers resting on the riverbed, each tilted a little.
    private var photoRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button { openPhoto = photo } label: {
                        PhotoSticker(photo: photo, glow: palette.colors[index % 3])
                            .frame(width: 130, height: 150)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -4 : 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(photo.caption.isEmpty ? "Grounding photo" : photo.caption)
                    .contextMenu {
                        Button("Remove", systemImage: "minus.circle") { withAnimation(.calm) { context.delete(photo) } }
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    /// Every value is the same size. What you care about doesn't shrink in a hard week.
    /// How much you've lived it lately shows only when you open one, as a ring.
    private func orbSize(_ value: PersonalValue) -> CGFloat { 62 }

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
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

/// The waterfall: a few soft strands of water falling down the left of the
/// page, melted together, with bright streaks sliding down them. Scrolling
/// nudges them along a little; deeper down, everything slows.
private struct Stream: View {
    /// 0 at the surface, 1 at the riverbed.
    let depth: Double
    let color: Color
    /// How far down the screen the water runs before it lands.
    var stopAt: CGFloat = .infinity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Each strand: sideways offset, width, and how its wave is shifted.
    private static let strands: [(dx: CGFloat, width: CGFloat, phase: Double)] = [
        (-6, 4, 0), (0, 6, 1.7), (6, 3.5, 3.1), (11, 2, 4.4),
    ]
    /// A bright streak sliding down one strand.
    private struct Streak {
        let strand: Int
        let speed: Double
        let length: CGFloat
        let start: Double
    }

    /// Fourteen streaks with varied speeds and lengths, the same every time.
    private static let streaks: [Streak] = {
        var result: [Streak] = []
        for i in 0..<14 {
            let speed: Double = 40 + Double((i * 37) % 30)
            let length: CGFloat = 16 + CGFloat((i * 13) % 20)
            let start: Double = Double(i) * 97
            result.append(Streak(strand: i % 4, speed: speed, length: length, start: start))
        }
        return result
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // Drawn in screen space: from the top of the screen to the bottom.
                let top: CGFloat = 0
                let bottom: CGFloat = min(size.height, stopAt)
                guard bottom > top else { return }
                // Nothing is drawn below where the falls land.
                ctx.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: bottom)))
                let calm = 1 - 0.6 * depth
                let x = AnchorsView.streamX

                func strandX(_ strand: Int, _ y: CGFloat) -> CGFloat {
                    let s = Self.strands[strand]
                    let wave: Double = sin(Double(y) / 110 + t * 0.5 + s.phase) * 3 * calm
                    return x + s.dx + CGFloat(wave)
                }

                // The body of the falls: strands melted into one soft sheet of water.
                var sheet = ctx
                sheet.opacity = 0.45
                sheet.addFilter(.alphaThreshold(min: 0.4, color: color))
                sheet.addFilter(.blur(radius: 4))
                sheet.drawLayer { layer in
                    for strand in Self.strands.indices {
                        var line = Path()
                        var y = top
                        line.move(to: CGPoint(x: strandX(strand, y), y: y))
                        while y < bottom {
                            y += 10
                            line.addLine(to: CGPoint(x: strandX(strand, y), y: y))
                        }
                        layer.stroke(line, with: .color(.black), lineWidth: Self.strands[strand].width)
                    }
                }

                // Bright streaks sliding down, like light catching falling water.
                // Their speed depends only on time, never on scrolling.
                let loop: Double = Double(size.height) + 40
                for streak in Self.streaks {
                    // Speed is fixed. (Multiplying the clock by something that changes
                    // while you scroll made the drops jump, since the clock is a huge number.)
                    let travel: Double = streak.start + t * streak.speed * 0.6
                    let fall: Double = travel.truncatingRemainder(dividingBy: loop)
                    let y: CGFloat = CGFloat(fall) - 40
                    let sx = strandX(streak.strand, y)
                    let rect = CGRect(x: sx - 1.2, y: y, width: 2.4, height: streak.length)
                    ctx.fill(Capsule().path(in: rect),
                             with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.85)]),
                                                   startPoint: CGPoint(x: sx, y: y),
                                                   endPoint: CGPoint(x: sx, y: y + streak.length)))
                }
            }
        }
    }
}

/// The riverbed: where the falls land and your values rest. Deeper water at
/// the top, warm sand and pebbles at the bottom, with soft light moving over it.
private struct Riverbed: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far above the values layer the bed starts fading in.
    static let fadeIn: CGFloat = 120

    private static let sand = Color(hex: 0xE3D3B4)
    private static let stone = Color(hex: 0xB9B2A6)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let bed = Path(CGRect(origin: .zero, size: size))
                let fade: CGFloat = Self.fadeIn / max(size.height, 1)

                // The water above flows straight into the bed: it starts fully
                // clear, gathers the same tint as the deep water, then turns to sand.
                ctx.fill(bed, with: .linearGradient(
                    Gradient(stops: [.init(color: color.opacity(0), location: 0),
                                     .init(color: color.opacity(0.16), location: fade),
                                     .init(color: color.opacity(0.26), location: fade + (1 - fade) * 0.4),
                                     .init(color: Self.sand.opacity(0.7), location: fade + (1 - fade) * 0.85),
                                     .init(color: Self.sand, location: 1)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

                // Light rippling across the water (caustics), very soft.
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 18))
                    for i in 0..<5 {
                        let k = Double(i)
                        let sx: Double = sin(t * 0.25 + k * 1.9) * 0.5 + 0.5
                        let sy: Double = cos(t * 0.2 + k * 1.3) * 0.25 + 0.3
                        let fx: Double = sx * Double(size.width)
                        let fy: Double = sy * Double(size.height)
                        layer.fill(Ellipse().path(in: CGRect(x: fx - 50, y: fy - 14, width: 100, height: 28)),
                                   with: .color(.white.opacity(0.35)))
                    }
                }

                // Where the waterfall lands: rings spreading out from the splash.
                let splash = CGPoint(x: AnchorsView.streamX, y: Self.fadeIn + 6)
                for i in 0..<3 {
                    let phase = (t * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    let r = CGFloat(8 + phase * 46)
                    ctx.stroke(Ellipse().path(in: CGRect(x: splash.x - r, y: splash.y - r * 0.35, width: r * 2, height: r * 0.7)),
                               with: .color(.white.opacity(0.6 * (1 - phase))), lineWidth: 1.5)
                }

                // Pebbles along the bottom: the same layout every time.
                for i in 0..<26 {
                    let fx: Double = (Double(i) * 0.618).truncatingRemainder(dividingBy: 1)
                    let fy: Double = (Double(i * 7) * 0.31).truncatingRemainder(dividingBy: 1)
                    let px: CGFloat = CGFloat(fx) * size.width
                    let py: CGFloat = size.height - 10 - CGFloat(fy) * 34
                    let w: CGFloat = 9 + CGFloat(i % 4) * 4
                    let rect = CGRect(x: px - w / 2, y: py - w * 0.3, width: w, height: w * 0.6)
                    ctx.fill(Ellipse().path(in: rect), with: .color(Self.stone.opacity(0.35 + Double(i % 3) * 0.12)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Adding an anchor

/// One place to add any kind of anchor.
private struct AddAnchorSheet: View {
    enum Kind: String, CaseIterable, Identifiable {
        case win = "a win", laugh = "a laugh", words = "words", value = "a value", photo = "a photo"
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
    @State private var photoItem: PhotosPickerItem?
    @State private var sticker: StickerMaker.Result?
    @State private var makingSticker = false
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage

    @State private var laughItem: PhotosPickerItem?
    @State private var laughImage: Data?

    private var canAdd: Bool {
        switch kind {
        case .photo: sticker != nil
        case .laugh: laughImage != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

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
                case .laugh:
                    Section {
                        TextField("The joke, the moment, what they said", text: $text, axis: .vertical)
                        PhotosPicker(selection: $laughItem, matching: .images) {
                            Label(laughImage == nil ? "Add a screenshot or photo (optional)" : "Choose a different one",
                                  systemImage: "photo")
                        }
                        if let laughImage, let image = UIImage(data: laughImage) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                        }
                    } footer: {
                        Text("A meme, a comic, something a friend said. Anything that made you laugh.")
                    }
                    .onChange(of: laughItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                laughImage = Laugh.shrink(data)
                            }
                        }
                    }
                case .words:
                    Section {
                        TextField("Something you'd want to hear when it's a lot", text: $text, axis: .vertical)
                    } footer: {
                        Text("For example: I can feel uncertain and still take one step.")
                    }
                case .photo:
                    Section {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(sticker == nil ? "Choose a photo" : "Choose a different photo", systemImage: "photo")
                        }
                        if makingSticker {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Making it a sticker…").foregroundStyle(.secondary)
                            }
                        } else if let sticker, let image = UIImage(data: sticker.png) {
                            StickerView(image: image, isCutout: sticker.isCutout, glow: palette.colors[0])
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .listRowBackground(Color.clear)
                        }
                        TextField("What it reminds you of (optional)", text: $meaning, axis: .vertical)
                    } footer: {
                        Text("A place, a person, a pet, anything that steadies you. If there's someone or something in front, it's lifted out like a sticker, right on your phone.")
                    }
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        makingSticker = true
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                sticker = await StickerMaker.make(from: data)
                            }
                            makingSticker = false
                        }
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
                        .disabled(!canAdd)
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
        case .laugh:
            context.insert(Laugh(text: main, imageData: laughImage))
        case .words:
            context.insert(SavedReminder(text: main))
        case .value:
            context.insert(PersonalValue(name: main, meaning: extra))
        case .photo:
            guard let sticker else { return }
            context.insert(GroundingPhoto(imageData: sticker.png, isCutout: sticker.isCutout, caption: extra))
        }
        try? context.save()
        dismiss()
        onAdded()
    }
}

/// One thing that made you laugh: the picture if there is one, then the words.
struct LaughCard: View {
    let laugh: Laugh
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if !laugh.text.isEmpty {
                Text(laugh.text)
                    .font(.system(.body, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: laugh.persistentModelID) {
            image = laugh.imageData.flatMap(UIImage.init(data:))
        }
    }
}

/// One grounding photo, up close, with what it reminds you of.
private struct PhotoCloseUp: View {
    let photo: GroundingPhoto
    let glow: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                PhotoSticker(photo: photo, glow: glow, border: 9)
                    .padding(.horizontal, 40)
                    .frame(maxHeight: 420)
                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .font(.system(.title3, design: .serif))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .themedBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

/// Decodes a grounding photo once, not on every scroll, and shows it as a sticker.
struct PhotoSticker: View {
    let photo: GroundingPhoto
    let glow: Color
    var border: CGFloat = 6
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                StickerView(image: image, isCutout: photo.isCutout, glow: glow, border: border)
            } else {
                Color.clear
            }
        }
        .task(id: photo.persistentModelID) {
            image = UIImage(data: photo.imageData)
        }
    }
}

// MARK: - Wins kept over time

/// One win's words, shared by the surface cards and the kept list.
private struct WinContent: View {
    let win: Win

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(win.text)
                Spacer(minLength: 8)
                if win.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Kept at the surface")
                }
            }
            if !win.meaning.isEmpty {
                Text(win.meaning).font(.callout).foregroundStyle(.secondary)
            }
            Text(win.effortLabel.lowercased())
                .font(.caption)
                .foregroundStyle(.tint)
        }
    }
}

/// Long-press actions for a win: keep it at the surface, let it settle, or remove it.
private struct WinMenu: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasHeldWin") private var hasHeldWin = false
    let win: Win

    var body: some View {
        Button(win.isPinned ? "Let it settle" : "Keep at the surface",
               systemImage: win.isPinned ? "pin.slash" : "pin") {
            hasHeldWin = true
            withAnimation(.calm) { win.isPinned.toggle() }
        }
        Button("Remove", systemImage: "minus.circle") {
            hasHeldWin = true
            withAnimation(.calm) { context.delete(win) }
        }
    }
}

/// A smooth stone resting just under the surface wins: everything older lives inside it.
private struct KeptStone: View {
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Ellipse()
                    .fill(LinearGradient(colors: [color.opacity(0.55), color.opacity(0.25)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 34)
                Ellipse()
                    .fill(.white.opacity(0.5))
                    .frame(width: 16, height: 6)
                    .offset(x: -8, y: -8)
                    .blur(radius: 1.5)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("kept over time")
                    .font(.system(.headline, design: .serif))
                Text("\(count) earlier \(count == 1 ? "win" : "wins"), still true")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.thinMaterial, in: Capsule())
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Every win that has settled, by month. Nothing here ever disappears on its own.
struct KeptWinsView: View {
    @Query(sort: \Win.createdAt, order: .reverse) private var wins: [Win]

    private var months: [(title: String, wins: [Win])] {
        let settled = Win.split(wins).settled
        let grouped = Dictionary(grouping: settled) {
            Calendar.current.dateInterval(of: .month, for: $0.createdAt)?.start ?? $0.createdAt
        }
        return grouped.keys.sorted(by: >).map { start in
            (start.formatted(.dateTime.month(.wide).year()).lowercased(), grouped[start] ?? [])
        }
    }

    var body: some View {
        List {
            Section {
                Text("Wins settle here after about two weeks. They're still yours, and still true. Long-press one to keep it at the surface.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(months, id: \.title) { month in
                Section(month.title) {
                    ForEach(month.wins) { win in
                        WinContent(win: win)
                            .padding(.vertical, 4)
                            .contextMenu { WinMenu(win: win) }
                    }
                }
            }
        }
        .themedBackground()
        .paperList()
        .navigationTitle("kept over time")
        .navigationBarTitleDisplayMode(.inline)
    }
}
