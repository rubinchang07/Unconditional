import SwiftUI
import SwiftData
import PencilKit

/// The daily flow, one calm step per screen:
/// 1. choose how to start (Write, Speak, Draw)
/// 2. get it out
/// 3. name the loop and save
/// Saving then offers the optional Reframe step.
struct TodayView: View {
    @Environment(\.modelContext) private var context

    private enum Step: Int, CaseIterable { case choose, capture, loop }
    @State private var step: Step = .choose

    @State private var kind: EntryKind = .write
    @State private var text = ""
    @State private var drawing = PKDrawing()
    @State private var tool = DrawingTool()
    @State private var canvasBackground: CanvasBackground = .paper
    @State private var loop: Loop?

    @State private var recorder = VoiceRecorder()
    /// Text that was already there when you pressed record, so new speech adds to it.
    @State private var textBeforeRecording = ""

    /// When set, the "reframe this?" sheet opens for that entry.
    @State private var savedEntry: Entry?
    @State private var showBreathing = false

    private var hasContent: Bool {
        if recorder.isRecording { return false }
        return kind.isText
            ? !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !drawing.strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                StepDots(count: Step.allCases.count, current: step.rawValue)

                // Each step slides in; `.id` tells SwiftUI it's a new view so the transition runs.
                Group {
                    switch step {
                    case .choose: chooseStep
                    case .capture: captureStep
                    case .loop: loopStep
                    }
                }
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(ThemeBackground())
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .choose {
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
        }
    }

    // MARK: - Step 1: choose

    private var chooseStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                PaperHeading(title: Greeting.now, subtitle: Greeting.dailyPrompt)
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

                Button {
                    showBreathing = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wind")
                            .foregroundStyle(.tint)
                        Text("Feeling a lot right now? Breathe for a minute first.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(14)
                    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("No right way to do this. Just get it out of your head.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Step 2: capture

    private var captureStep: some View {
        VStack(spacing: 20) {
            switch kind {
            case .write:
                PaperHeading(title: "What's on your mind?", subtitle: "Write it the way you'd say it. Messy is fine.")
                JournalEditor(text: $text, placeholder: "Start anywhere…")
            case .speak:
                PaperHeading(title: "Say it out loud", subtitle: "Transcribed on your phone. Fix any words after you stop.")
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
                    Button("Clear drawing", role: .destructive) { drawing = PKDrawing() }
                        .font(.footnote)
                }
            }

            Button("Next") { go(to: .loop) }
                .buttonStyle(.paper)
                .disabled(!hasContent)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Step 3: loop

    private var loopStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                PaperHeading(title: "Which loop is this?",
                             subtitle: "Naming the pattern makes it a little smaller. It's okay not to be sure.")
                    .padding(.bottom, 8)

                LoopChoices(selection: $loop)

                Button("Save entry", action: save)
                    .buttonStyle(.paper)
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Actions

    private func go(to newStep: Step) {
        withAnimation(.easeInOut(duration: 0.35)) { step = newStep }
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
        if kind == .draw { entry.drawingBackground = canvasBackground.rawValue }
        try? context.save()

        // Reset for next time, then offer the reframe step.
        text = ""
        textBeforeRecording = ""
        drawing = PKDrawing()
        loop = nil
        step = .choose
        savedEntry = entry
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
private struct StepDots: View {
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
        .frame(maxHeight: .infinity)
        .paperCard(padding: 14)
    }
}

/// Loop cards, each with its core belief, plus "Not sure yet".
private struct LoopChoices: View {
    @Binding var selection: Loop?
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]

    var body: some View {
        ForEach(loops) { loop in
            choice(isSelected: selection == loop, action: { selection = loop }) {
                Text(loop.name)
                    .font(.system(.headline, design: .serif))
                Text("“\(loop.coreBelief)”")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        choice(isSelected: selection == nil, action: { selection = nil }) {
            Text("Not sure yet")
                .font(.system(.headline, design: .serif))
        }
    }

    private func choice(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> some View) -> some View {
        Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6, content: content)
                Spacer(minLength: 12)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .paperCard(padding: 16)
            .overlay(
                RoundedRectangle(cornerRadius: Paper.cornerRadius, style: .continuous)
                    .strokeBorder(.tint.opacity(isSelected ? 0.6 : 0), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    .background(Circle().fill(recorder.isRecording ? AnyShapeStyle(Color.red.opacity(0.75)) : AnyShapeStyle(.tint)))
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
                    .foregroundStyle(.red)
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
                        Image(systemName: "leaf")
                            .font(.system(size: 40))
                            .foregroundStyle(.tint)
                        Text("Saved.")
                            .font(.system(.title, design: .serif).weight(.semibold))
                        Text("Getting it out counts. Want to look at it from another angle, or just be kind to yourself about it?")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reframe this thought") { withAnimation { step = .reframe } }
                            .buttonStyle(.paper)
                        Button("Self-compassion break instead") { withAnimation { step = .compassion } }
                        Button("Not today") { dismiss() }
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ThemeBackground())
                case .reframe:
                    ReframeView(entry: entry, onDone: { withAnimation { step = .win } })
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

/// "Remember this?" One random past win, shown after a reframe.
struct WinReminderView: View {
    @Query private var wins: [Win]
    @Query private var values: [PersonalValue]
    @State private var value: PersonalValue?
    let onDone: () -> Void

    /// Picked once when the view appears, so it doesn't change on every redraw.
    @State private var win: Win?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            if let win {
                Text("Remember this?")
                    .font(.system(.title, design: .serif).weight(.semibold))
                VStack(spacing: 8) {
                    Text(win.text)
                        .font(.system(.title3, design: .serif))
                    if !win.meaning.isEmpty {
                        Text(win.meaning)
                            .foregroundStyle(.secondary)
                    }
                    Text(win.createdAt, format: .dateTime.month().day())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .paperCard()
                Text("One hard moment doesn't erase this. Both are true.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if let value {
                    Text("And you still care about **\(value.name)**, whatever today brought.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Nice work.")
                    .font(.system(.title, design: .serif).weight(.semibold))
                Text("Next time something goes right, even something small, log it in Wins. You'll see it here after a reframe.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.paper)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackground())
        .onAppear {
            win = wins.randomElement()
            value = values.randomElement()
        }
    }
}
