import SwiftUI
import SwiftData
import PencilKit

/// The daily flow, one calm step per screen:
/// 0. home: the orb, a greeting, and one main action ("Check in")
/// 1. choose how to start (Write, Speak, Draw, Words)
/// 2. get it out: only the page, the voice, the canvas, or one word, nothing else
/// 3. how does this sit? one slider (Words skips it, since sliding the words already said)
/// 4. which loop, if any, and save
/// One thing per screen, on purpose: a check-in should never feel like a form.
/// Saving then offers the optional Reframe step, or for a light moment, a place in Anchors.
struct TodayView: View {
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable { case home, choose, capture, sit, loop }
    @State private var step: Step = .home
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage

    @State private var kind: EntryKind = .write
    @State private var text = ""
    @State private var drawing = PKDrawing()
    @State private var tool = DrawingTool()
    @State private var canvasBackground: CanvasBackground = .paper
    @State private var loop: Loop?
    /// "How does this sit?", 0 heavy to 1 light. Only saved once something set it.
    @State private var lightness = 0.5
    @State private var lightnessSet = false
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
    /// Starting points for writing, tucked behind one small icon.
    @State private var showPrompts = false
    /// The opening: 0 nothing, 1 the orb swells in, 2 the greeting, 3 everything else.
    @State private var introStage = Intro.played ? 3 : 0
    @Environment(\.accessibilityReduceMotion) private var introReduceMotion
    /// Becomes true the first time you hold the orb, and the hint under it goes away for good.
    @AppStorage("hasHeldOrb") private var hasHeldOrb = false
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]
    /// Parked thoughts. On Sundays, a quiet note on Today offers a calm look at them.
    @Query(filter: #Predicate<ParkedThought> { $0.reviewedAt == nil }) private var parked: [ParkedThought]
    @State private var showReview = false

    private var hasContent: Bool {
        if recorder.isRecording { return false }
        return kind.isText
            ? !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !drawing.strokes.isEmpty
    }

    /// The check-in's screens for this kind of entry, after home.
    private var flow: [Step] {
        kind == .words ? [.choose, .capture, .loop] : [.choose, .capture, .sit, .loop]
    }

    private func back() {
        guard let index = flow.firstIndex(of: step) else { return go(to: .home) }
        go(to: index == 0 ? .home : flow[index - 1])
    }

    private func next() {
        guard let index = flow.firstIndex(of: step), index + 1 < flow.count else { return }
        go(to: flow[index + 1])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if step != .home {
                    // Dots for the check-in steps (home doesn't count).
                    StepDots(count: flow.count, current: flow.firstIndex(of: step) ?? 0)
                }

                // Each step slides in; `.id` tells SwiftUI it's a new view so the transition runs.
                Group {
                    switch step {
                    case .home: homeStep
                    case .choose: chooseStep
                    case .capture: captureStep
                    case .sit: sitStep
                    case .loop: loopStep
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
                        Button("Back", systemImage: "chevron.left") { back() }
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
            .sheet(isPresented: $showReview) { NavigationStack { ParkedReviewView() } }
            .sheet(item: $savedGood) { entry in GoodMomentSheet(entry: entry) }
            .sheet(isPresented: $showPrompts) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("a starting point")
                        .font(.system(.headline, design: .serif))
                    SituationPrompts(text: $text)
                }
                .padding(20)
                .presentationDetents([.height(160)])
                .presentationDragIndicator(.visible)
                .onChange(of: text) { _, _ in showPrompts = false }
            }
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
            // One way in for every kind of moment. You say how it sits after it's out,
            // so a good moment and a hard one start the same way.
            Button("Check in") { go(to: .choose) }
                .buttonStyle(.paper)

            Button { showReset = true } label: {
                Label("i'm spiraling", systemImage: "wind").pill()
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            // Only on Sundays, and only when something's waiting. No section of its own.
            if ReminderScheduler.isReviewDay(.now) && !parked.isEmpty {
                Button { showReview = true } label: {
                    Label("it's sunday. \(parked.count) parked thought\(parked.count == 1 ? "" : "s") to look at",
                          systemImage: "tray")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

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

    /// Four soft tiles, an icon and a word each. Nothing else to read.
    private var chooseStep: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            Text("How do you want to start?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .softCase()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(EntryKind.allCases) { option in
                    Button {
                        // Words keeps its own format, so switching to or from it starts fresh.
                        if kind != option && (kind == .words || option == .words) { text = "" }
                        kind = option
                        go(to: .capture)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: option.symbol)
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 54, height: 54)
                                .background(.tint.opacity(0.12), in: Circle())
                            Text(option.label)
                                .font(.system(.body, design: .serif).weight(.semibold))
                                .softCase()
                        }
                        .frame(maxWidth: .infinity, minHeight: 130)
                        .paperCard(padding: 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(option.invitation)
                }
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Step 2: capture. Only the place to get it out.

    private var captureStep: some View {
        Group {
            switch kind {
            case .write:
                WriteSurface(text: $text, onPrompts: { showPrompts = true })
                    .padding(.bottom, 12)
            case .speak:
                speakSurface
            case .draw:
                drawSurface
            case .words:
                WordScramble(text: $text) { lean in
                    // The words already said how it sits, so they set it.
                    lightness = (lean + 1) / 2
                    lightnessSet = true
                }
            }
        }
        // "Next" only appears once there's something to keep, so the first thing
        // you see is just the page. Drawing keeps it from the start, so the canvas
        // doesn't jump under your pen.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasContent || kind == .draw {
                bottomBar("Next", action: next)
                    .disabled(!hasContent)
                    .transition(.opacity)
            }
        }
        .animation(.calm, value: hasContent)
    }

    private func bottomBar(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.paper)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background { FadingThemeBar() }
    }

    /// The orb is the button: tap to talk, tap to stop. Your words appear under it.
    private var speakSurface: some View {
        ScrollView {
            VStack(spacing: 18) {
                Button {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        textBeforeRecording = text
                        Task { await recorder.start() }
                    }
                } label: {
                    OrbView(palette: orbPalette, state: recorder.isRecording ? .listening : .resting,
                            level: recorder.level, exercise: true)
                        .frame(width: 200, height: 200)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 40)
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

                Text(recorder.isRecording ? "listening… tap to stop" : "tap the orb to talk")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .softCase()

                if let message = recorder.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !text.isEmpty || recorder.isRecording {
                    TextField("", text: $text, axis: .vertical)
                        .font(.system(.title3, design: .serif))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .disabled(recorder.isRecording)
                        .padding(.horizontal, 8)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .animation(.calm, value: text.isEmpty)
    }

    /// The canvas takes the whole page; its tools float on it in one small capsule.
    private var drawSurface: some View {
        DrawingCanvas(drawing: $drawing, tool: tool, background: canvasBackground)
            .clipShape(RoundedRectangle(cornerRadius: Paper.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
            .overlay(alignment: .topLeading) { drawingTools.padding(10) }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 4)
    }

    // MARK: - Step 3: how does this sit?

    private var sitStep: some View {
        SitView(lightness: $lightness, isSet: lightnessSet) { lightnessSet = true }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar(lightnessSet ? "Next" : "Skip", action: next)
            }
    }

    // MARK: - Step 4: which loop, then save

    private var loopStep: some View {
        ScrollView {
            LoopChips(loop: $loop)
                .padding(.top, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar("Save entry", action: save)
        }
    }

    // MARK: Drawing

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
        entry.loop = loop
        if lightnessSet {
            entry.lightness = lightness
            entry.isGood = lightness >= Entry.lightThreshold
        }
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
        lightness = 0.5
        lightnessSet = false
        step = .home
        // A light moment gets a warm "kept"; a heavier one is offered a reframe.
        if entry.isGood {
            savedGood = entry
        } else {
            savedEntry = entry
        }
    }
}

private extension EntryKind {
    var invitation: String {
        switch self {
        case .write: "Type it out, at your own pace"
        case .speak: "Talk it through, I'll write it down"
        case .draw: "When words aren't there yet"
        case .words: "When full sentences won't come"
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

/// The whole page is paper to write on: larger serif words, one soft
/// placeholder, and a faint lightbulb for a starting point if you want one.
private struct WriteSurface: View {
    @Binding var text: String
    let onPrompts: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("What's on your mind?")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .lineSpacing(6)
                .focused($focused)
        }
        .font(.system(.title3, design: .serif))
        .frame(maxHeight: .infinity)
        .paperCard(padding: 18)
        .overlay(alignment: .bottomTrailing) {
            if text.isEmpty {
                Button("A starting point", systemImage: "lightbulb", action: onPrompts)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, height: 44)
                    .padding(6)
                    .transition(.opacity)
            }
        }
        .animation(.calm, value: text.isEmpty)
        .onAppear { focused = true }
    }
}

/// "Which loop is this?" as a row of small chips under what you wrote.
/// Tap one to tag it, tap it again to untag. Leaving them all off is fine.
private struct LoopChips: View {
    @Binding var loop: Loop?
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
                Text("Part of a loop?")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .softCase()
                    .padding(.bottom, 8)
            }

            if compact {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) { chips }
                }
                .scrollIndicators(.hidden)
            } else {
                ChipFlow { chips }
            }

            if naming {
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
            if let loop, !loop.coreBelief.isEmpty {
                Text("“\(loop.coreBelief)”")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.calm, value: loop)
        .animation(.calm, value: naming)
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(loops) { option in
            chip(option.name, isOn: loop == option) {
                loop = loop == option ? nil : option
            }
        }
        if !naming {
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

/// Shown right after saving: reframe now or skip. After a reframe,
/// it shows one of your past wins, to counter the habit of discounting them.
struct ReframePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    let entry: Entry

    private enum Step { case ask, reframe, stream, shift, compassion, win }
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
                        Text("Getting it out counts. What would help now?")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Look at it another way") { withAnimation { step = .reframe } }
                            .buttonStyle(.paper)
                        Button("Stop the stream here") { withAnimation { step = .stream } }
                            .buttonStyle(.paper)
                        Button("Not today") { dismiss() }
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ThemeBackground())
                case .reframe:
                    ReframeView(entry: entry, onDone: { withAnimation { step = entry.reframe == nil ? .win : .shift } },
                                onCompassion: { withAnimation { step = .compassion } })
                case .stream:
                    StreamDamView(words: StreamWords.pieces(text: entry.text, kind: entry.kind, loop: entry.loop?.name),
                                  onDone: { dismiss() })
                case .shift:
                    if let reframe = entry.reframe {
                        ShiftView(reframe: reframe) { withAnimation { step = .win } }
                    }
                case .compassion:
                    SelfCompassionView(entry: entry, onDone: { withAnimation { step = .win } })
                case .win:
                    WinReminderView(onDone: { dismiss() })
                }
            }
        }
        .presentationDetents(step == .ask ? [.fraction(0.62)] : [.large])
        .presentationCornerRadius(28)
    }
}

/// Right after a reframe, once: how heavy it felt before, and now, as two orbs.
/// It's only here, in the moment it means something, not saved up into a chart.
private struct ShiftView: View {
    let reframe: Reframe
    let onDone: () -> Void

    private var message: String {
        let change = reframe.distressBefore - reframe.distressAfter
        if change >= 1 { return "It feels a little lighter than when you started." }
        if change <= -1 { return "It feels heavier right now. Looking closely can stir things up, and that's okay." }
        return "About the same. Some thoughts take more than one look."
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            DistressOrbs(before: reframe.distressBefore, after: reframe.distressAfter)
            Text(message)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
            Spacer()
            Button("Continue", action: onDone)
                .buttonStyle(.paper)
                .padding(.bottom, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackground())
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

/// "How does this sit?": the orb, one slider from heavy to light, and nothing else.
/// The orb warms and opens as you slide toward light. Skipping is fine,
/// because a check-in doesn't have to be sorted into good or bad.
private struct SitView: View {
    @Binding var lightness: Double
    let isSet: Bool
    let onTouch: () -> Void
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage

    private var isLight: Bool { isSet && lightness >= Entry.lightThreshold }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            Text("How does this sit?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .softCase()
            OrbView(palette: orbPalette, speed: 0.5, state: isLight ? .glowing : .resting, warm: isLight)
                .saturation(isSet ? 0.55 + 0.45 * lightness : 0.7)
                .brightness(isSet ? 0.06 * (lightness - 0.5) : 0)
                .scaleEffect(isSet ? 0.85 + 0.25 * lightness : 0.95)
                .frame(width: 170, height: 170)
            VStack(spacing: 6) {
                Slider(value: $lightness, in: 0...1, onEditingChanged: { editing in
                    if editing { onTouch() }
                })
                .accessibilityLabel("How does this sit")
                .accessibilityValue(isSet ? description : "Not set")
                HStack {
                    Text("heavy")
                    Spacer()
                    Text("light")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .onChange(of: lightness) { _, _ in if !isSet { onTouch() } }
        .animation(.calm, value: isLight)
    }

    private var description: String {
        switch lightness {
        case ..<0.2: "Heavy"
        case ..<0.45: "A bit heavy"
        case ..<0.6: "In between"
        case ..<0.8: "A bit light"
        default: "Light"
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
