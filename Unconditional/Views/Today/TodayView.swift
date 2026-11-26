import SwiftUI
import SwiftData
import PencilKit

/// The daily flow, one calm step per screen:
/// 0. home: the orb, a greeting, and one main action ("Check in")
/// 1. choose how to start (Write, Speak, Draw)
/// 2. get it out, optionally tap the loop it belongs to, and save
/// Saving then offers the optional Reframe step.
struct TodayView: View {
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable { case home, choose, capture }
    @State private var step: Step = .home
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage

    @State private var kind: EntryKind = .write
    @State private var text = ""
    @State private var drawing = PKDrawing()
    @State private var tool = DrawingTool()
    @State private var canvasBackground: CanvasBackground = .paper
    @State private var loop: Loop?
    /// This check-in is about something good, not something hard.
    @State private var good = false
    /// When set, the "kept" sheet for a good moment opens.
    @State private var savedGood: Entry?

    @State private var recorder = VoiceRecorder()
    /// Text that was already there when you pressed record, so new speech adds to it.
    @State private var textBeforeRecording = ""

    /// When set, the "reframe this?" sheet opens for that entry.
    @State private var savedEntry: Entry?
    @State private var showBreathing = false
    @State private var showGrounding = false
    @State private var showTension = false
    @State private var showSteps = false
    @State private var showReset = false
    @State private var showSettings = false
    @State private var showValues = false
    @State private var saveFailed = false
    @State private var showDrawingTools = false
    /// The color to go back to after the eraser.
    @State private var lastInk: InkChoice = .ink
    @State private var showInkPicker = false
    /// The drawing page doesn't scroll under your finger. It only moves with the
    /// small handle on the canvas's edge, so we move it ourselves rather than
    /// using a scroll view (which kept competing with the pen).
    @State private var drawOffset: CGFloat = 0
    @State private var drawContentHeight: CGFloat = 0
    @State private var drawVisibleHeight: CGFloat = 600
    @State private var handleStart: CGFloat?
    /// The opening: 0 nothing, 1 the orb swells in, 2 the greeting, 3 everything else.
    @State private var introStage = Intro.played ? 3 : 0
    @Environment(\.accessibilityReduceMotion) private var introReduceMotion
    /// Becomes true the first time you hold the orb, and the hint under it goes away for good.
    @AppStorage("hasHeldOrb") private var hasHeldOrb = false
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]

    private var hasContent: Bool {
        if recorder.isRecording { return false }
        return kind.isText
            ? !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !drawing.strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if step != .home {
                    // Dots for the check-in steps (home doesn't count).
                    StepDots(count: Step.allCases.count - 1, current: step.rawValue - 1)
                }

                // Each step slides in; `.id` tells SwiftUI it's a new view so the transition runs.
                Group {
                    switch step {
                    case .home: homeStep
                    case .choose: chooseStep
                    case .capture: captureStep
                    }
                }
                .id(step)
                // A soft fade with a slight lift: calmer than sliding sideways.
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)),
                                        removal: .opacity))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(ThemeBackground())
            .navigationTitle(step == .home ? "" : Date.now.formatted(.dateTime.weekday(.wide).month().day()).lowercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step == .home {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") { showSettings = true }
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Thought reset", systemImage: "leaf") { showReset = true }
                    }
                }
                if step != .home {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { go(to: Step(rawValue: step.rawValue - 1)!) }
                    }
                }
            }
            .keyboardDoneButton()
            .onChange(of: recorder.transcript) { _, spoken in
                text = textBeforeRecording.isEmpty ? spoken : textBeforeRecording + " " + spoken
            }
            .onChange(of: step) { _, _ in
                if recorder.isRecording { recorder.stop() }
            }
            .sheet(item: $savedEntry) { entry in
                ReframePromptView(entry: entry)
            }
            .sheet(isPresented: $showBreathing) { BreathingView() }
            .sheet(isPresented: $showGrounding) { GroundingView() }
            .sheet(isPresented: $showTension) { TensionReleaseView() }
            .sheet(isPresented: $showSteps) { StepPathsView() }
            .fullScreenCover(isPresented: $showReset) { ThoughtResetView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $savedGood) { entry in GoodMomentSheet(entry: entry) }
            .alert("couldn't save just now", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your entry is still here. Try saving again in a moment.")
            }
        }
    }

    // MARK: - Home: one calm screen, one main action

    private var homeStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            if showValues {
                ValuesBloom(values: values, palette: orbPalette) {
                    withAnimation(.calm) { showValues = false }
                }
                .frame(height: 330)
                .transition(.opacity)
            } else {
                // Hold the orb and it divides into your values.
                OrbView(palette: orbPalette, interactive: true, onHold: openValues)
                .frame(width: 260, height: 260)
                // Opening: the orb swells in past its size, then settles back.
                .scaleEffect(introStage >= 1 ? 1 : 0.35)
                .opacity(introStage >= 1 ? 1 : 0)
                .transition(.opacity)
                .overlay {
                    // The orb itself is hidden from VoiceOver, so this stands in for it.
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel("Show your values")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { openValues() }
                        .allowsHitTesting(false)
                }
            }
            if !showValues {
            VStack(spacing: 10) {
                // A quiet, wordless hint, shown until you've held the orb once.
                if !hasHeldOrb {
                    HoldCue()
                        .transition(.opacity)
                }
                Text(Greeting.now)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .softCase()
            }
            .transition(.opacity)
            .opacity(introStage >= 2 ? 1 : 0)
            .offset(y: introStage >= 2 ? 0 : 10)
            }
            Spacer(minLength: 12)

            VStack(spacing: 18) {
            Button("Check in") {
                good = false
                go(to: .choose)
            }
                .buttonStyle(.paper)

            // Same size on purpose: a good moment is as worth keeping as a hard one is worth working through.
            HStack(spacing: 12) {
                Button {
                    good = true
                    go(to: .choose)
                } label: {
                    Label("something good", systemImage: "sun.max").pill()
                }
                Button { showReset = true } label: {
                    Label("i'm spiraling", systemImage: "wind").pill()
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            // Everything else stays tucked away until you want it.
            Menu {
                Section("calm your body") {
                    Button("Breathe for a minute", systemImage: "wind") { showBreathing = true }
                    Button("5-4-3-2-1 grounding", systemImage: "hand.raised") { showGrounding = true }
                    Button("Release tension", systemImage: "figure.cooldown") { showTension = true }
                }
                Button("One step at a time", systemImage: "shoeprints.fill") { showSteps = true }
            } label: {
                Label("more", systemImage: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .padding(.bottom, 12)
            }
            .opacity(introStage >= 3 ? 1 : 0)
            .offset(y: introStage >= 3 ? 0 : 14)
            .allowsHitTesting(introStage >= 3)
        }
        // Tap anywhere to skip the opening and get straight to the buttons.
        .overlay {
            if introStage < 3 {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { skipIntro() }
                    .accessibilityHidden(true)
            }
        }
        .task { await playIntro() }
    }

    private func skipIntro() {
        withAnimation(.easeOut(duration: 0.35)) { introStage = 3 }
    }

    /// Plays once per launch: the orb swells in alone, then the words, then the choices.
    private func playIntro() async {
        guard introStage < 3 else { return }
        Intro.played = true
        if introReduceMotion {
            introStage = 3
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard introStage < 1 else { return }
        withAnimation(.spring(duration: 2.8, bounce: 0.4)) { introStage = 1 }
        try? await Task.sleep(for: .milliseconds(2600))
        guard introStage < 2 else { return }
        withAnimation(.easeOut(duration: 1.0)) { introStage = 2 }
        try? await Task.sleep(for: .milliseconds(700))
        guard introStage < 3 else { return }
        withAnimation(.easeOut(duration: 1.0)) { introStage = 3 }
    }

    // MARK: - Step 1: choose how to start

    private var chooseStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                if good {
                    OrbView(palette: orbPalette, speed: 0.35, warm: true)
                        .frame(width: 64, height: 64)
                        .padding(.vertical, 6)
                }
                PaperHeading(title: good ? "Something good" : "How do you want to start?",
                             subtitle: good ? "Big or small, it counts. How do you want to keep it?"
                                            : "No right way to do this. Just get it out of your head.")
                    .padding(.bottom, 8)

                ForEach(EntryKind.allCases) { option in
                    Button {
                        kind = option
                        go(to: .capture)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.symbol)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 48, height: 48)
                                .background(.tint.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.label)
                                    .font(.system(.title3, design: .serif).weight(.semibold))
                                Text(option.invitation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .paperCard(padding: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Step 2: capture

    private var captureStep: some View {
        Group {
            if kind == .draw {
                drawPage
            } else {
                // Everything scrolls, so the keyboard never hides your words.
                ScrollView {
                    captureContent
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        // Save sits in a bar of its own, above the tab bar, so it's always in reach.
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
    }

    private var saveBar: some View {
        Button(good ? "Keep it" : "Save entry", action: save)
            .buttonStyle(.paper)
            .disabled(!hasContent)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background { FadingThemeBar() }
    }

    // MARK: Drawing

    /// The drawing page: no scroll view at all, so every touch on the canvas is a stroke.
    /// The handle slides the whole page up to reach the loop chips below.
    private var drawPage: some View {
        GeometryReader { proxy in
            captureContent
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { drawContentHeight = $0 }
                .offset(y: -min(drawOffset, maxDrawOffset))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .onAppear { drawVisibleHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, height in drawVisibleHeight = height }
        }
        // Hide what slides above the top, but let the canvas shadow spill sideways.
        .mask(Rectangle().padding(.horizontal, -20).padding(.bottom, -40))
    }

    private var maxDrawOffset: CGFloat { max(0, drawContentHeight - drawVisibleHeight) }

    /// Most of the screen, leaving room to glimpse what's below.
    private var canvasHeight: CGFloat { max(300, drawVisibleHeight * 0.82) }
    private let handleLength: CGFloat = 54
    private let handleInset: CGFloat = 18

    /// A short vertical bar on the canvas's right edge. Hold and move it to slide the
    /// page; drawing anywhere else on the canvas never moves the page.
    /// It lives on the canvas and never leaves it: top of the canvas means the top of
    /// the page, bottom of the canvas means the bottom. The canvas itself slides up a
    /// little as you go, and the math below keeps the bar under your finger anyway.
    private var pageHandle: some View {
        let track = max(1, canvasHeight - 2 * handleInset - handleLength)
        let fraction = min(max(drawOffset / maxDrawOffset, 0), 1)
        // On screen the bar sits at  -offset + fraction * track,  so for every point the
        // finger moves, the page moves  1 / (track / max - 1)  points.
        let pagePerPoint = 1 / max(track / max(maxDrawOffset, 1) - 1, 0.25)
        let held = handleStart != nil
        return Capsule()
            .fill(.secondary.opacity(held ? 0.8 : 0.5))
            .frame(width: held ? 8 : 6, height: handleLength)
            .frame(width: 44, height: handleLength + 28) // a bigger, invisible target for your thumb
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = handleStart ?? drawOffset
                        if handleStart == nil { handleStart = start }
                        let target = start + drag.translation.height * pagePerPoint
                        drawOffset = min(max(target, 0), maxDrawOffset)
                    }
                    .onEnded { _ in
                        handleStart = nil
                    }
            )
            .padding(.top, handleInset - 14 + fraction * track)
            .padding(.trailing, 2)
            .animation(.calm, value: held)
            .sensoryFeedback(.selection, trigger: held)
            .accessibilityElement()
            .accessibilityLabel("Scroll page")
            .accessibilityHint("Swipe up or down to move the page without drawing.")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 160 : -160
                withAnimation(.calm) { drawOffset = min(max(drawOffset + step, 0), maxDrawOffset) }
            }
    }

    /// A small floating capsule on the canvas: color, eraser, undo, and the rest of the tools.
    private var drawingTools: some View {
        HStack(spacing: 0) {
            Button { showInkPicker = true } label: {
                Circle()
                    .fill(Color(uiColor: lastInk.uiColor))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 2))
                    .opacity(tool.ink == .eraser ? 0.5 : 1)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Color, \(lastInk.name)")
            .popover(isPresented: $showInkPicker) {
                InkPalette(selection: $tool.ink)
                    .padding(8)
                    .presentationCompactAdaptation(.popover)
            }

            Button {
                tool.ink = tool.ink == .eraser ? lastInk : .eraser
            } label: {
                Image(systemName: tool.ink == .eraser ? "eraser.fill" : "eraser")
                    .foregroundStyle(tool.ink == .eraser ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Eraser")
            .accessibilityAddTraits(tool.ink == .eraser ? .isSelected : [])

            Button {
                guard !drawing.strokes.isEmpty else { return }
                drawing = PKDrawing(strokes: drawing.strokes.dropLast())
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(drawing.strokes.isEmpty)
            .accessibilityLabel("Undo last stroke")

            Button { showDrawingTools = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Brushes and paper")
        }
        .font(.system(size: 16))
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .onChange(of: tool.ink) { _, ink in
            if ink != .eraser { lastInk = ink }
            showInkPicker = false
        }
        .sheet(isPresented: $showDrawingTools) {
            VStack(spacing: 18) {
                Text("brushes and paper")
                    .font(.system(.headline, design: .serif))
                BrushBar(tool: $tool)
                BackgroundPicker(selection: $canvasBackground)
                if !drawing.strokes.isEmpty {
                    Button("clear drawing") {
                        withAnimation(.calm) { drawing = PKDrawing() }
                        showDrawingTools = false
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var captureContent: some View {
        VStack(spacing: 20) {
            switch kind {
            case .write:
                if good {
                    // Small and slow while you write, so it keeps you company without pulling focus.
                    OrbView(palette: orbPalette, speed: 0.35, warm: true)
                        .frame(width: 56, height: 56)
                        .padding(.top, 4)
                }
                PaperHeading(title: good ? "What went well?" : "What's on your mind?",
                             subtitle: good ? "Even a little. Good moments count as much as hard ones."
                                            : "Write it the way you'd say it. Messy is fine.")
                SituationPrompts(text: $text, good: good)
                JournalEditor(text: $text, placeholder: "Start anywhere…")
            case .speak:
                PaperHeading(title: good ? "Tell me what went well" : "Say it out loud",
                             subtitle: "Transcribed on your phone. Fix any words after you stop.")
                // The orb listens: it grows gently with your voice while recording.
                OrbView(palette: orbPalette, state: recorder.isRecording ? .listening : .resting, level: recorder.level, warm: good,
                        exercise: true)
                    .frame(width: 130, height: 130)
                    .padding(.vertical, 8)
                SpeakControls(recorder: recorder, onStart: { textBeforeRecording = text })
                    .paperCard()
                JournalEditor(text: $text, placeholder: "Your words will appear here…")
                    .disabled(recorder.isRecording)
            case .draw:
                // The canvas gets the room; the tools float on it in one small capsule.
                DrawingCanvas(drawing: $drawing, tool: tool, background: canvasBackground)
                    .frame(height: canvasHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Paper.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
                    .overlay(alignment: .topLeading) { drawingTools.padding(10) }
                    .overlay(alignment: .topTrailing) {
                        if maxDrawOffset > 1 { pageHandle }
                    }
            }

            // Optional: which loop this belongs to, or that it was good after all.
            // Never required, so it never stands between you and saving.
            LoopChips(loop: $loop, good: $good)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    private func openValues() {
        withAnimation(.calm) {
            showValues = true
            hasHeldOrb = true
        }
    }

    private func go(to newStep: Step) {
        withAnimation(.calm) { step = newStep }
    }

    private func save() {
        let entry = Entry(
            kind: kind,
            text: kind.isText ? text : "",
            drawingData: kind == .draw ? drawing.dataRepresentation() : nil
        )
        // Insert first, then link relationships: SwiftData is happiest when both
        // sides of a relationship already belong to the same context.
        context.insert(entry)
        entry.loop = good ? nil : loop
        entry.isGood = good
        if kind == .draw { entry.drawingBackground = canvasBackground.rawValue }
        do {
            try context.save()
        } catch {
            // Undo the half-made entry, keep what you wrote on screen, and say so.
            context.rollback()
            saveFailed = true
            return
        }

        // Reset for next time, then offer the reframe step.
        text = ""
        textBeforeRecording = ""
        drawing = PKDrawing()
        loop = nil
        step = .home
        // A good moment gets a warm "kept"; a hard one is offered a reframe.
        if good {
            savedGood = entry
        } else {
            savedEntry = entry
        }
        good = false
    }
}

private extension EntryKind {
    var invitation: String {
        switch self {
        case .write: "Type it out, at your own pace"
        case .speak: "Talk it through, I'll write it down"
        case .draw: "When words aren't there yet"
        }
    }
}

/// The theme's background fading in from clear, behind the Save bar,
/// so content scrolling underneath softens instead of cutting off.
private struct FadingThemeBar: View {
    @AppStorage(Theme.storageKey) private var theme: Theme = .white

    var body: some View {
        theme.background
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.35)],
                                 startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea(edges: .bottom)
    }
}

private extension View {
    /// A soft, tinted pill: clearly a button, quieter than "Check in".
    func pill() -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(.tint.opacity(0.13), in: Capsule())
            .contentShape(Capsule())
    }
}

/// Remembers that the opening has played, so switching tabs doesn't replay it.
private enum Intro {
    static var played = false
}

/// Time-of-day greeting.
enum Greeting {
    static var now: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}

/// Small progress dots: the current step is a longer pill.
struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.tint.opacity(0.2)))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

/// A TextEditor on a paper card, with placeholder text.
private struct JournalEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .lineSpacing(5)
        }
        .font(.system(.body, design: .serif))
        .frame(minHeight: 260)
        .paperCard(padding: 14)
    }
}

/// "Which loop is this?" as a row of small chips under what you wrote.
/// Tap one to tag it, tap it again to untag. Leaving them all off is fine.
/// "Something good" sits in the same row, for when it turned out to be good.
private struct LoopChips: View {
    @Binding var loop: Loop?
    @Binding var good: Bool
    /// One scrolling row instead of wrapping lines, so drawing keeps its space.
    var compact = false
    @Environment(\.modelContext) private var context
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @State private var naming = false
    @State private var newLoop = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !compact {
                Text(good ? "Kept as something good" : "Which loop is this? (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if compact {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) { chips }
                }
                .scrollIndicators(.hidden)
            } else {
                ChipFlow { chips }
            }

            if naming && !good {
                HStack {
                    TextField("Name the loop", text: $newLoop)
                        .focused($nameFocused)
                        .onSubmit(addLoop)
                    Button("Add", action: addLoop)
                        .disabled(newLoop.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .paperCard(padding: 14)
            }

            // Seeing the belief written down makes it a little easier to question.
            if let loop, !loop.coreBelief.isEmpty, !good {
                Text("“\(loop.coreBelief)”")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.calm, value: loop)
        .animation(.calm, value: good)
        .animation(.calm, value: naming)
    }

    @ViewBuilder
    private var chips: some View {
        if !good {
            ForEach(loops) { option in
                chip(option.name, isOn: loop == option) {
                    loop = loop == option ? nil : option
                }
            }
        }
        chip("something good", systemImage: "sun.max", isOn: good) {
            good.toggle()
            if good { loop = nil }
        }
        if !good && !naming {
            chip("new loop", systemImage: "plus", isOn: false) {
                naming = true
                nameFocused = true
            }
        }
    }

    private func chip(_ title: String, systemImage: String? = nil, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).imageScale(.small) }
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.secondary.opacity(0.08)), in: Capsule())
            .overlay(Capsule().strokeBorder(.tint.opacity(isOn ? 0.5 : 0), lineWidth: 1))
            .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func addLoop() {
        let name = newLoop.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let existing = loops.first(where: { $0.name.lowercased() == name.lowercased() }) {
            loop = existing
        } else {
            let created = Loop(name: name, coreBelief: "", pattern: "", sortOrder: (loops.map(\.sortOrder).max() ?? -1) + 1)
            context.insert(created)
            loop = created
        }
        newLoop = ""
        naming = false
    }
}

/// The big record button plus status and errors.
private struct SpeakControls: View {
    let recorder: VoiceRecorder
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    onStart()
                    Task { await recorder.start() }
                }
            } label: {
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(recorder.isRecording ? AnyShapeStyle(.tint.opacity(0.6)) : AnyShapeStyle(.tint)))
                    .symbolEffect(.pulse, isActive: recorder.isRecording)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

            Text(recorder.isRecording ? "Listening… tap to stop" : "Tap to start talking")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let message = recorder.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Shown right after saving: reframe now or skip. After a reframe,
/// it shows one of your past wins, to counter the habit of discounting them.
struct ReframePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    let entry: Entry

    private enum Step { case ask, reframe, compassion, win }
    @State private var step: Step = .ask

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .ask:
                    VStack(spacing: 18) {
                        Spacer()
                        OrbView(palette: orbPalette, state: .settling)
                            .frame(width: 110, height: 110)
                        Text("Saved.")
                            .font(.system(.title, design: .serif).weight(.semibold))
                        Text("Getting it out counts. Want to look at it from another angle?")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Look at it another way") { withAnimation { step = .reframe } }
                            .buttonStyle(.paper)
                        Button("Not today") { dismiss() }
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ThemeBackground())
                case .reframe:
                    ReframeView(entry: entry, onDone: { withAnimation { step = .win } },
                                onCompassion: { withAnimation { step = .compassion } })
                case .compassion:
                    SelfCompassionView(entry: entry, onDone: { withAnimation { step = .win } })
                case .win:
                    WinReminderView(onDone: { dismiss() })
                }
            }
        }
        .presentationDetents(step == .ask ? [.medium] : [.large])
        .presentationCornerRadius(28)
    }
}

/// Shown after a reframe or self-compassion break. Leads with a value, because
/// your worth doesn't depend on past success. A past win is there if you want it.
struct WinReminderView: View {
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    @Query private var wins: [Win]
    @Query private var values: [PersonalValue]
    @Query private var reminders: [SavedReminder]
    let onDone: () -> Void

    /// Picked once when the view appears, so they don't change on every redraw.
    @State private var value: PersonalValue?
    @State private var reminder: SavedReminder?
    @State private var win: Win?
    @State private var showWin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // The orb settles into a calm, steady shape while the message appears.
                OrbView(palette: orbPalette, state: .settling)
                    .frame(width: 120, height: 120)
                    .padding(.top, 32)

                if let value {
                    Text("Whatever today brought")
                        .font(.system(.title, design: .serif).weight(.semibold))
                    VStack(spacing: 8) {
                        Text("you still care about")
                            .foregroundStyle(.secondary)
                        Text(value.name)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(.tint)
                        if !value.meaning.isEmpty {
                            Text(value.meaning)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .paperCard()
                    Text("That's true on good days and hard ones. Your worth isn't something today could take away.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else if let reminder {
                    Text("Something you wanted to remember")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(reminder.text)
                        .font(.system(.title3, design: .serif))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .paperCard()
                } else {
                    Text("Your worth isn't on the line here.")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("You looked at a hard thought honestly. That's enough for now. If you'd like, add a few values in Anchors, and you'll see one here next time.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                // Wins are optional here: nice to remember, but not the reason you're okay.
                if let win {
                    if showWin {
                        VStack(spacing: 6) {
                            Text(win.text)
                                .font(.system(.body, design: .serif))
                            Text(win.createdAt, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .paperCard(padding: 16)
                        .transition(.opacity)
                    } else {
                        Button("Show me a past win too") { withAnimation { showWin = true } }
                            .font(.subheadline)
                    }
                }

                Button("Done", action: onDone)
                    .buttonStyle(.paper)
                    .padding(.top, 12)
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .background(ThemeBackground())
        .onAppear {
            value = values.randomElement()
            reminder = reminders.randomElement()
            win = wins.randomElement()
        }
    }
}

/// After saving a good moment: a settling orb, a warm word, and the option to
/// keep it as a win too.
private struct GoodMomentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    let entry: Entry
    /// After "keep it as a win too": a small golden orb floats off toward Anchors.
    @State private var sendingToAnchors = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Group {
                if sendingToAnchors {
                    PinchOffOrb(palette: orbPalette, dropColor: Color(hex: 0xF6C38B))
                        .frame(width: 140, height: 140)
                } else {
                    OrbView(palette: orbPalette, state: .glowing, warm: true)
                        .frame(width: 110, height: 110)
                }
            }
            .frame(height: 140)
            Text("Saved to your journal.")
                .font(.system(.title, design: .serif).weight(.semibold))
            Text("Noticing good moments is a skill, just like working through hard ones. Want it in Anchors too, with your wins?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Add to Anchors") {
                let words = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = words.isEmpty ? "A good moment" : String(words.prefix(140))
                context.insert(Win(text: title))
                try? context.save()
                sendingToAnchors = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    dismiss()
                }
            }
            .buttonStyle(.paper)
            .disabled(sendingToAnchors)
            Button("Done") { dismiss() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationCornerRadius(28)
    }
}
