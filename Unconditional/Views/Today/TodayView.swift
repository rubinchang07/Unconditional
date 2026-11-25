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
    @State private var showReset = false
    @State private var showCareer = false
    @State private var showSettings = false
    @State private var showValues = false
    @State private var saveFailed = false
    /// Becomes true the first time you hold the orb, and the hint under it goes away for good.
    @AppStorage("hasHeldOrb") private var hasHeldOrb = false
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]
    @AppStorage(CareerReflection.enabledKey) private var careerEnabled = false

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
            .fullScreenCover(isPresented: $showReset) { ThoughtResetView() }
            .sheet(isPresented: $showCareer) { CareerReflectionView() }
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
                // A quiet hint, shown until you've found it once.
                if !hasHeldOrb {
                    Label("hold the orb to see what matters to you", systemImage: "hand.tap")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
                Text(Greeting.now)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .softCase()
                Text(Greeting.dailyPrompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }
            .transition(.opacity)
            }
            Spacer(minLength: 12)

            // Shows up only when there's a tiny step to ask about.
            TinyStepFollowUp()

            Button("Check in") {
                good = false
                go(to: .choose)
            }
                .buttonStyle(.paper)

            // Good moments are as easy to keep as hard ones are to work through.
            HStack(spacing: 28) {
                Button("something good", systemImage: "sun.max") {
                    good = true
                    go(to: .choose)
                }
                Button("i'm spiraling", systemImage: "wind") { showReset = true }
            }
            .font(.headline)
            .labelStyle(.titleOnly)
            .frame(minHeight: 44)
            .padding(.vertical, 6)

            // Everything else stays tucked away until you want it.
            Menu {
                Button("Breathe for a minute", systemImage: "wind") { showBreathing = true }
                if careerEnabled {
                    Button("Career check-in", systemImage: "briefcase") { showCareer = true }
                }
            } label: {
                Label("more", systemImage: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Step 1: choose how to start

    private var chooseStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                if good {
                    OrbView(palette: orbPalette, warm: true)
                        .frame(width: 80, height: 80)
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

    @ViewBuilder
    private var captureStep: some View {
        if kind == .draw {
            captureContent
        } else {
            // Writing and speaking scroll, so the keyboard never hides what you're typing.
            ScrollView {
                captureContent
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var captureContent: some View {
        VStack(spacing: 20) {
            switch kind {
            case .write:
                if good {
                    OrbView(palette: orbPalette, warm: true)
                        .frame(width: 70, height: 70)
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
                OrbView(palette: orbPalette, state: recorder.isRecording ? .listening : .resting, level: recorder.level, warm: good)
                    .frame(width: 130, height: 130)
                    .padding(.vertical, 8)
                SpeakControls(recorder: recorder, onStart: { textBeforeRecording = text })
                    .paperCard()
                JournalEditor(text: $text, placeholder: "Your words will appear here…")
                    .disabled(recorder.isRecording)
            case .draw:
                PaperHeading(title: "Draw it", subtitle: "Shapes, scribbles, a face. Whatever it feels like.")
                VStack(spacing: 12) {
                    InkPalette(selection: $tool.ink)
                    BrushBar(tool: $tool)
                    BackgroundPicker(selection: $canvasBackground)
                }
                .paperCard(padding: 14)
                DrawingCanvas(drawing: $drawing, tool: tool, background: canvasBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Paper.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
                if !drawing.strokes.isEmpty {
                    Button("clear drawing") { withAnimation(.calm) { drawing = PKDrawing() } }
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            // Optional: which loop this belongs to, or that it was good after all.
            // Never required, so it never stands between you and saving.
            LoopChips(loop: $loop, good: $good)

            Button(good ? "Keep it" : "Save entry", action: save)
            .buttonStyle(.paper)
            .disabled(!hasContent)
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

/// Time-of-day greeting and a gentle prompt that changes each day.
enum Greeting {
    static var now: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    static let prompts = [
        "What's taking up the most room in your head today?",
        "What felt heavy today, and what felt a little lighter?",
        "What would you want a friend to know about your day?",
        "Is there something you're being hard on yourself about?",
        "What are you afraid it means? Let's look at it together.",
        "What did you do today that took effort, even if it didn't work?",
        "What's one thing that's true about you no matter how today went?",
    ]

    /// Same prompt all day, a new one tomorrow.
    static var dailyPrompt: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return prompts[day % prompts.count]
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
    @Environment(\.modelContext) private var context
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @State private var naming = false
    @State private var newLoop = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(good ? "Kept as something good" : "Which loop is this? (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ChipFlow {
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
                                .foregroundStyle(.tertiary)
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

/// Follows up on tiny steps: did you give it a go? Effort is what counts here.
struct TinyStepFollowUp: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TinyStep> { $0.outcome == nil }, sort: \TinyStep.createdAt)
    private var steps: [TinyStep]

    /// Only steps from more than an hour ago, so it doesn't ask right away.
    private var due: TinyStep? {
        steps.first { $0.isOpen && $0.createdAt < Date.now.addingTimeInterval(-3600) }
    }

    var body: some View {
        if let step = due {
            VStack(alignment: .leading, spacing: 12) {
                Text("Earlier you picked a tiny step")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(step.text)
                    .font(.system(.body, design: .serif))
                Text("Did you give it a go? It doesn't matter how it went.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("I tried") { resolve(step, outcome: "tried") }
                        .buttonStyle(.borderedProminent)
                    Button("Not yet") {
                        withAnimation { step.snoozedUntil = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400) }
                        try? context.save()
                    }
                    .buttonStyle(.bordered)
                    Button("Let it go") { resolve(step, outcome: "letGo") }
                        .buttonStyle(.bordered)
                }
                .font(.subheadline)
            }
            .paperCard(padding: 16)
            .transition(.opacity)
        }
    }

    private func resolve(_ step: TinyStep, outcome: String) {
        withAnimation { step.outcome = outcome }
        try? context.save()
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
            Text("Kept.")
                .font(.system(.title, design: .serif).weight(.semibold))
            Text("Noticing good moments is a skill, just like working through hard ones. This one's yours now.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Keep it as a win too") {
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
            Button("Just keep it here") { dismiss() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationCornerRadius(28)
    }
}
