import SwiftUI
import SwiftData

/// "One step at a time": the things that feel daunting, each with a trail of footprints.
struct StepPathsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \StepPath.createdAt, order: .reverse) private var paths: [StepPath]
    @State private var adding = false
    @State private var newTitle = ""

    private var walking: [StepPath] { paths.filter { !$0.isResting } }
    private var resting: [StepPath] { paths.filter(\.isResting) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Something big or daunting gets a path. You don't plan it or measure it. You just leave a footprint each time you take a step, however small, and however it went.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                if paths.isEmpty {
                    GentleEmpty(symbol: "shoeprints.fill", title: "No paths yet",
                                message: "A job search, a hard conversation, a project you keep putting off. Name it, and start with one step.")
                        .listRowBackground(Color.clear)
                }

                if !walking.isEmpty {
                    Section("walking") {
                        ForEach(walking) { row($0) }
                    }
                }
                if !resting.isEmpty {
                    Section {
                        ForEach(resting) { row($0) }
                    } header: {
                        Text("resting")
                    } footer: {
                        Text("Set aside for now. Your footprints are still here whenever you come back.")
                    }
                }
            }
            .themedBackground()
            .paperList()
            .navigationTitle("one step at a time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Something daunting", systemImage: "plus") { adding = true }
                }
            }
            .alert("What feels daunting?", isPresented: $adding) {
                TextField("For example: finding a job", text: $newTitle)
                Button("Cancel", role: .cancel) { newTitle = "" }
                Button("Start a path") { addPath() }
            } message: {
                Text("A few words is enough.")
            }
        }
    }

    private func row(_ path: StepPath) -> some View {
        NavigationLink {
            PathView(path: path)
        } label: {
            HStack(spacing: 14) {
                Footprint(isLeft: true)
                    .frame(width: 14, height: 30)
                    .foregroundStyle(Sand.print)
                    .rotationEffect(.degrees(-8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(path.title)
                        .font(.system(.body, design: .serif))
                    let count = path.walked.count
                    Text(count == 0 ? "No steps yet" : "\(count) step\(count == 1 ? "" : "s") taken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button(path.isResting ? "Keep walking" : "Rest it for now",
                   systemImage: path.isResting ? "figure.walk" : "moon") {
                withAnimation(.calm) { path.isResting.toggle() }
            }
            Button("Remove", systemImage: "trash") {
                withAnimation(.calm) { context.delete(path) }
            }
        }
    }

    private func addPath() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTitle = ""
        guard !title.isEmpty else { return }
        withAnimation(.calm) { context.insert(StepPath(title: title)) }
    }
}

// MARK: - The path itself

/// One path as footprints in the sand, walking up the screen from the first step.
/// The newest print sits at the top, closest to the horizon.
///
/// "A hard day" lets the tide come in over the sand, as high as the day felt,
/// and then go back out. The prints are all still there afterwards: a setback
/// is part of the walk, never a step backward and never an eraser.
struct PathView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let path: StepPath
    @State private var takingStep = false
    @State private var stepText = ""
    /// The print you just made, so it can press into the sand.
    @State private var freshID: PersistentIdentifier?
    @State private var pressCount = 0
    // The tide
    @State private var markingTide = false
    @State private var tideText = ""
    @State private var tideHeaviness = 0.5
    @State private var surgeAt: Date?
    @State private var surgeReach = 0.0
    /// The hard day just marked, so we can ask what it taught you once the water's gone.
    @State private var askingLearned: Footstep?
    @State private var learnedText = ""
    @FocusState private var learnedFocused: Bool
    /// Where the water is drawn on screen, so each print knows when it's under it.
    @State private var waterFrame: CGRect = .zero

    /// Vertical room for each print.
    private let rowHeight: CGFloat = 86

    var body: some View {
        let steps = path.walked
        let printIndex = Dictionary(uniqueKeysWithValues: steps.enumerated().map { ($0.element.persistentModelID, $0.offset) })
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    horizon
                        .id("top")
                    // Newest first, so the trail runs from the bottom of the screen upward.
                    ForEach(Array(path.everything.reversed())) { item in
                        if item.isTide {
                            tideRow(item)
                        } else {
                            printRow(item, index: printIndex[item.persistentModelID] ?? 0)
                        }
                    }
                    if steps.isEmpty {
                        Text("Your first footprint will appear here.")
                            .font(.callout)
                            .foregroundStyle(Sand.ink.opacity(0.7))
                            .padding(.top, 40)
                    }
                    Text("started \(path.createdAt.formatted(.dateTime.month(.wide).day()))")
                        .font(.caption)
                        .foregroundStyle(Sand.ink.opacity(0.6))
                        .padding(.vertical, 28)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 120)
            }
            .defaultScrollAnchor(.bottom)
            .background {
                SandBackground(reduceMotion: reduceMotion, surgeAt: surgeAt, surgeReach: surgeReach)
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { waterFrame = $0 }
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if let tide = askingLearned {
                        learnedCard(tide)
                    } else {
                        VStack(spacing: 6) {
                            Button("Take a step") { takingStep = true }
                                .buttonStyle(.paper)
                            Button("a hard day", systemImage: "water.waves") { markingTide = true }
                                .font(.subheadline)
                                .foregroundStyle(Sand.ink.opacity(0.8))
                                .frame(minHeight: 44)
                        }
                        .disabled(surgeAt != nil)
                        .opacity(surgeAt != nil ? 0.4 : 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .animation(.calm, value: askingLearned == nil)
            }
            .navigationTitle(path.title.lowercased())
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: pressCount)
            .sheet(isPresented: $takingStep) {
                stepSheet(onSave: {
                    withAnimation(.calm) { reader.scrollTo("top", anchor: .top) }
                })
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $markingTide) {
                tideSheet
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// The thing you're walking toward, faint, like a shape on the horizon.
    /// No distance, no percentage: just the direction.
    private var horizon: some View {
        VStack(spacing: 6) {
            Text("toward")
                .font(.caption)
                .foregroundStyle(Sand.ink.opacity(0.6))
            Text(path.title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Sand.ink.opacity(0.8))
                .multilineTextAlignment(.center)
            Text("Every print counts the same, however it went.")
                .font(.footnote)
                .foregroundStyle(Sand.ink.opacity(0.65))
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    /// One footprint, swaying left and right along a gently winding path,
    /// with what you did written beside it.
    private func printRow(_ step: Footstep, index: Int) -> some View {
        let isLeft = index.isMultiple(of: 2)
        // The trail winds slowly; left and right feet sit either side of it.
        let sway = CGFloat(sin(Double(index) * 0.7)) * 46 + (isLeft ? -16 : 16)
        let tilt = cos(Double(index) * 0.7) * 14
        let age = Date.now.timeIntervalSince(step.createdAt) / 86_400
        let fresh = freshID == step.persistentModelID
        return ZStack {
            WashablePrint(isLeft: isLeft, tilt: tilt, softness: Footstep.softness(age: age), seed: Double(index),
                          surgeAt: surgeAt, reach: surgeReach, water: waterFrame)
                .overlay {
                    if fresh && !reduceMotion {
                        SandBurst(isLeft: isLeft)
                            .frame(width: 200, height: 200)
                            .allowsHitTesting(false)
                            .id(pressCount)
                    }
                }
                .offset(x: sway)

            // What you did, on the side with more room.
            Text(step.text)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(Sand.ink)
                .lineLimit(3)
                .frame(width: 130, alignment: sway < 0 ? .leading : .trailing)
                .multilineTextAlignment(sway < 0 ? .leading : .trailing)
                .offset(x: sway < 0 ? sway + 100 : sway - 100)
        }
        .frame(minHeight: rowHeight)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // A new print presses in: a touch bigger at first, then settling into the sand.
        .transition(.scale(scale: 1.3).combined(with: .opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step: \(step.text), \(step.createdAt.formatted(date: .abbreviated, time: .omitted))")
        .contextMenu {
            Button("Remove this step", systemImage: "trash") {
                withAnimation(.calm) { context.delete(step) }
            }
        }
    }

    /// A hard day in the trail: a faint line of water where the tide reached, and
    /// what it was, if you said. It sits between the prints, taking none away.
    private func tideRow(_ tide: Footstep) -> some View {
        VStack(spacing: 5) {
            TideLine()
                .stroke(Sand.water.opacity(0.45 + 0.5 * tide.heaviness),
                        style: StrokeStyle(lineWidth: 1.5 + 2 * tide.heaviness, lineCap: .round))
                .frame(height: 12)
                .padding(.horizontal, 70)
            Text(tide.text.isEmpty ? "a hard day" : tide.text)
                .font(.system(.footnote, design: .serif))
                .italic()
                .foregroundStyle(Sand.ink.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            if !tide.learned.isEmpty {
                Label(tide.learned, systemImage: "leaf")
                    .font(.caption)
                    .foregroundStyle(Sand.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A hard day\(tide.text.isEmpty ? "" : ": \(tide.text)"), \(tide.createdAt.formatted(date: .abbreviated, time: .omitted))\(tide.learned.isEmpty ? "" : ". Learned: \(tide.learned)")")
        .contextMenu {
            Button("Remove", systemImage: "trash") {
                withAnimation(.calm) { context.delete(tide) }
            }
        }
    }

    /// Just how hard, and a few words if you want. The water shows the rest.
    private var tideSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text("how hard was it?")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                VStack(spacing: 4) {
                    Slider(value: $tideHeaviness, in: 0...1)
                        .accessibilityLabel("How hard was it")
                    HStack {
                        Text("a little")
                        Spacer()
                        Text("very")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                TextField("a few words (optional)", text: $tideText, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                Button("Let the tide come in", action: markTide)
                    .buttonStyle(.paper)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { markingTide = false }
                }
            }
        }
    }

    /// After the water goes back out: one small card in place of the buttons,
    /// one question, one field. Leaving it empty is fine.
    private func learnedCard(_ tide: Footstep) -> some View {
        HStack(spacing: 10) {
            TextField("anything you learned?", text: $learnedText, axis: .vertical)
                .lineLimit(1...3)
                .focused($learnedFocused)
                .submitLabel(.done)
                .onSubmit { closeLearned(tide) }
            Button(learnedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "not now" : "keep") {
                closeLearned(tide)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func closeLearned(_ tide: Footstep) {
        tide.learned = learnedText.trimmingCharacters(in: .whitespacesAndNewlines)
        learnedText = ""
        learnedFocused = false
        withAnimation(.calm) { askingLearned = nil }
    }

    private func markTide() {
        let text = tideText.trimmingCharacters(in: .whitespacesAndNewlines)
        let heaviness = tideHeaviness
        tideText = ""
        tideHeaviness = 0.5
        markingTide = false
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            let tide = Footstep(text: text)
            tide.isTide = true
            tide.heaviness = heaviness
            withAnimation(.calm) {
                context.insert(tide)
                tide.path = path
            }
            // The water rises as high as the day felt, then goes back out.
            if !reduceMotion {
                surgeReach = Footstep.tideReach(heaviness: heaviness)
                surgeAt = .now
                // A little longer than the water, so the prints can dry off.
                try? await Task.sleep(for: .seconds(SandBackground.surgeDuration + 1.5))
                surgeAt = nil
            }
            withAnimation(.calm) { askingLearned = tide }
        }
    }

    private func stepSheet(onSave: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("What did you do?")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                Text("Small counts. Opening the document counts. Sending one email counts. How it went doesn't change the print.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("One step I took", text: $stepText, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                Button("Leave a footprint") {
                    leavePrint()
                    onSave()
                }
                .buttonStyle(.paper)
                .disabled(stepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { takingStep = false }
                }
            }
        }
    }

    private func leavePrint() {
        let text = stepText.trimmingCharacters(in: .whitespacesAndNewlines)
        stepText = ""
        takingStep = false
        guard !text.isEmpty else { return }
        // Let the sheet slide away first, then press the print into the sand.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.6, bounce: 0.45)) {
                let step = Footstep(text: text)
                context.insert(step)
                step.path = path
                if path.isResting { path.isResting = false }
                freshID = step.persistentModelID
            }
            pressCount += 1
        }
    }
}

// MARK: - Sand

enum Sand {
    static let light = Color(light: 0xF4EBDD, dark: 0x2A251E)
    static let deep = Color(light: 0xEADBC4, dark: 0x221E18)
    /// A pressed print: a little darker than the sand around it.
    static let print = Color(light: 0xD7C3A4, dark: 0x3A3228)
    static let rim = Color(light: 0xFBF5EC, dark: 0x4A4136)
    static let ink = Color(light: 0x5B4A36, dark: 0xE4D6C2)
    static let water = Color(light: 0x8FBFCB, dark: 0x4D7A86)
    /// Sand with water in it.
    static let wet = Color(light: 0xA8906D, dark: 0x1E1A15)
}

/// One footprint, which comes alive a little when the tide runs over it:
/// it darkens like wet sand, rocks gently in the water, catches a shimmer of
/// light, and lets a few tiny bubbles go. As the water leaves it dries off and
/// settles back, exactly where it was. It never fades or washes away.
struct WashablePrint: View {
    let isLeft: Bool
    let tilt: Double
    let softness: Double
    let seed: Double
    let surgeAt: Date?
    let reach: Double
    /// The water's frame on screen.
    let water: CGRect
    @State private var midY: CGFloat = 0

    var body: some View {
        TimelineView(.animation(paused: surgeAt == nil)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let wet = wetness(at: timeline.date)
            Footprint(isLeft: isLeft)
                .frame(width: 26, height: 56)
                .foregroundStyle(Sand.print)
                .overlay {
                    // Wet sand is darker.
                    Footprint(isLeft: isLeft).fill(Sand.wet.opacity(0.6 * wet))
                }
                .overlay {
                    // A lighter rim, like the sand pushed up around the print,
                    // catching the light while it's under water.
                    Footprint(isLeft: isLeft)
                        .stroke(Sand.rim.opacity(1 - 0.4 * wet), lineWidth: 1.2)
                        .offset(x: -0.8, y: -1)
                    Footprint(isLeft: isLeft)
                        .stroke(.white.opacity(0.55 * wet * (0.5 + 0.5 * sin(t * 3 + seed))), lineWidth: 1.6)
                }
                .overlay {
                    if wet > 0.05 { bubbles(t: t, wet: wet) }
                }
                .rotationEffect(.degrees(tilt + 4 * wet * sin(t * 1.5 + seed)))
                .offset(x: 3 * wet * sin(t * 1.8 + seed), y: 1.5 * wet * cos(t * 1.3 + seed))
                .opacity(softness)
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { midY = $0 }
    }

    /// A few tiny bubbles drifting up from the print, then gone.
    private func bubbles(t: Double, wet: Double) -> some View {
        Canvas { ctx, size in
            for i in 0..<3 {
                let phase = (t * 14 + Double(i) * 12 + seed * 7).truncatingRemainder(dividingBy: 36)
                let x = size.width / 2 + CGFloat(sin(t * 2 + Double(i) * 2 + seed)) * 7
                let y = size.height / 2 - CGFloat(phase)
                let r: CGFloat = 1.4 + CGFloat(i) * 0.5
                ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(.white.opacity(0.7 * wet * (1 - phase / 36))), lineWidth: 0.8)
            }
        }
        .frame(width: 40, height: 80)
        .allowsHitTesting(false)
    }

    /// How wet the print is right now: under the water, or only just uncovered.
    private func wetness(at date: Date) -> Double {
        guard let surgeAt, water.height > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(surgeAt)
        func waterY(_ e: Double) -> CGFloat {
            water.maxY - water.height * CGFloat(0.05 + SandBackground.surge(elapsed: e) * reach)
        }
        let now = Self.wetness(printY: midY, waterY: waterY(elapsed))
        // Sand stays dark for a moment after the water leaves it.
        let moment = Self.wetness(printY: midY, waterY: waterY(elapsed - 1.2))
        return max(now, 0.7 * moment)
    }

    /// 0 above the waterline, easing to 1 about 60 points under it.
    static func wetness(printY: CGFloat, waterY: CGFloat) -> Double {
        Double(min(max((printY - waterY) / 60, 0), 1))
    }
}

/// A soft wave line, for where the tide reached.
struct TideLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for x in stride(from: rect.minX, through: rect.maxX, by: 2) {
            path.addLine(to: CGPoint(x: x, y: rect.midY + rect.height * 0.35 * sin((x - rect.minX) / 14)))
        }
        return path
    }
}

/// Warm sand, with a soft wash of water easing in and out along the bottom.
/// On a hard day the tide surges up the sand, as high as `surgeReach`, and recedes.
struct SandBackground: View {
    var reduceMotion: Bool
    var surgeAt: Date? = nil
    /// How far up the screen the tide reaches at its height, 0 to 1.
    var surgeReach: Double = 0

    /// Rising, a pause at the top, then going back out.
    static let surgeDuration = 6.0

    /// How far along the tide is, 0 to 1 and back to 0: in over 1.6 seconds,
    /// holding for a moment, then out slowly. Smooth at both ends.
    static func surge(elapsed t: Double) -> Double {
        func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return x * x * (3 - 2 * x) }
        if t <= 0 || t >= surgeDuration { return 0 }
        if t < 1.6 { return ease(t / 1.6) }
        if t < 2.6 { return 1 }
        return 1 - ease((t - 2.6) / (surgeDuration - 2.6))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Sand.light, Sand.deep]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                // The wash: a slow, wavy edge of water that comes up a little and goes back.
                let tide = surgeAt.map { Self.surge(elapsed: timeline.date.timeIntervalSince($0)) * surgeReach } ?? 0
                let reach = size.height * (0.05 + 0.025 * (reduceMotion ? 0 : sin(t * 0.35)) + tide)
                var water = Path()
                water.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0, through: size.width, by: 6) {
                    let y = size.height - reach + (5 + 7 * tide) * sin(x / 38 + t * 0.6)
                    water.addLine(to: CGPoint(x: x, y: y))
                }
                water.addLine(to: CGPoint(x: size.width, y: size.height))
                water.closeSubpath()
                ctx.fill(water, with: .color(Color(light: 0xCFE3E8, dark: 0x1F2C30).opacity(0.55)))
                ctx.stroke(water, with: .color(.white.opacity(0.5)), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Sand kicked up as a foot presses in: grains spray out from the edges of the print,
/// mostly from the toes and heel where a foot pushes hardest, arc up a little, fall
/// back with gravity, and settle in a soft ring of displaced sand that fades.
struct SandBurst: View {
    var isLeft: Bool
    @State private var start = Date.now
    @State private var finished = false

    private static let duration = 1.3

    private struct Grain {
        var origin: CGPoint      // where on the print's edge it starts, relative to the middle
        var velocity: CGVector   // points per second
        var size: CGFloat
        var shade: Int           // 0 light, 1 mid, 2 dark sand
        var delay: Double
    }

    /// Made once per burst, so each step's spray is a little different.
    @State private var grains: [Grain] = SandBurst.makeGrains()

    private static func makeGrains() -> [Grain] {
        (0..<90).map { _ in
            // Toes (top) and heel (bottom) throw the most sand.
            let fromToes = Double.random(in: 0...1) < 0.45
            let fromHeel = !fromToes && Double.random(in: 0...1) < 0.55
            let angle: Double
            if fromToes { angle = Double.random(in: -.pi * 0.95 ... -.pi * 0.05) }      // up and out
            else if fromHeel { angle = Double.random(in: .pi * 0.1 ... .pi * 0.9) }       // down and out
            else { angle = Bool.random() ? Double.random(in: -0.5...0.5) : Double.random(in: .pi - 0.5 ... .pi + 0.5) }
            // Start on the edge of an ellipse about the size of the print.
            let origin = CGPoint(x: cos(angle) * 13, y: sin(angle) * 28)
            let speed = Double.random(in: 40...120)
            return Grain(origin: origin,
                         velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - Double.random(in: 30...80)),
                         size: CGFloat.random(in: 1.2...3.2),
                         shade: Int.random(in: 0...2),
                         delay: Double.random(in: 0...0.12))
        }
    }

    var body: some View {
        if !finished {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    let mid = CGPoint(x: size.width / 2, y: size.height / 2)
                    let shades = [Sand.rim, Sand.print, Sand.ink.opacity(0.55)]

                    // Displaced sand: a soft ring pushed out around the print, fading.
                    let ringProgress = min(elapsed / 0.5, 1)
                    let ringFade = max(0, 1 - elapsed / Self.duration)
                    let ring = CGRect(x: mid.x - 16 - 6 * ringProgress, y: mid.y - 32 - 8 * ringProgress,
                                      width: 32 + 12 * ringProgress, height: 64 + 16 * ringProgress)
                    ctx.stroke(Path(ellipseIn: ring), with: .color(Sand.rim.opacity(0.8 * ringFade)), lineWidth: 3)

                    for grain in grains {
                        let t = elapsed - grain.delay
                        guard t > 0 else { continue }
                        // Thrown, then pulled back down, slowing as it lands.
                        let drag = 1 - min(t / Self.duration, 1) * 0.6
                        let x = grain.origin.x + grain.velocity.dx * t * drag
                        let y = grain.origin.y + grain.velocity.dy * t * drag + 160 * t * t
                        let fade = max(0, 1 - t / (Self.duration - grain.delay))
                        let r = grain.size / 2
                        ctx.fill(Path(ellipseIn: CGRect(x: mid.x + x - r, y: mid.y + y - r, width: r * 2, height: r * 2)),
                                 with: .color(shades[grain.shade].opacity(fade)))
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(Self.duration + 0.1))
                finished = true
            }
        }
    }
}

// MARK: - A footprint

/// A bare footprint: heel, a narrower arch, the ball of the foot, and five toes.
/// Drawn as one shape so it can be filled, stroked, and mirrored for the other foot.
struct Footprint: Shape {
    var isLeft: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        // Sole: heel at the bottom, ball near the top, a slightly narrower arch between.
        // Joined with `union`, so it's one outline (overlapping pieces don't cut holes).
        var sole = Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.66, width: w * 0.62, height: h * 0.32))   // heel
            .union(Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.24, width: w * 0.84, height: h * 0.40)))   // ball
            .union(Path(roundedRect: CGRect(x: w * 0.24, y: h * 0.46, width: w * 0.48, height: h * 0.32),
                        cornerRadius: w * 0.2))                                                          // arch
        // Toes, biggest on the inside of the foot (drawn here as a right foot).
        let toes: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (0.22, 0.12, 0.17), (0.45, 0.07, 0.12), (0.62, 0.08, 0.105), (0.77, 0.12, 0.09), (0.89, 0.19, 0.075),
        ]
        for toe in toes {
            let r = toe.r * w
            sole = sole.union(Path(ellipseIn: CGRect(x: toe.x * w - r, y: toe.y * h - r * 0.9, width: r * 2, height: r * 1.8)))
        }
        var path = sole.offsetBy(dx: rect.minX, dy: rect.minY)
        // Mirror for the left foot.
        if isLeft {
            path = path.applying(CGAffineTransform(translationX: rect.midX, y: 0).scaledBy(x: -1, y: 1).translatedBy(x: -rect.midX, y: 0))
        }
        return path
    }
}
