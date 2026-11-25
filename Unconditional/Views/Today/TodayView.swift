import SwiftUI
import SwiftData
import PencilKit

/// Start of the daily flow: choose Write, Speak, or Draw, get it out, tag the loop, save.
/// Saving offers the optional Reframe step.
struct TodayView: View {
    @Environment(\.modelContext) private var context

    @State private var kind: EntryKind = .write
    @State private var text = ""
    @State private var drawing = PKDrawing()
    @State private var loop: Loop?

    @State private var recorder = VoiceRecorder()
    /// Text that was already there when you pressed record, so new speech adds to it.
    @State private var textBeforeRecording = ""

    /// When set, the "reframe this?" sheet opens for that entry.
    @State private var savedEntry: Entry?

    private var canSave: Bool {
        if recorder.isRecording { return false }
        return kind.isText
            ? !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !drawing.strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("How do you want to start?", selection: $kind) {
                        ForEach(EntryKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("No right way to do this. Just get it out of your head.")
                }

                switch kind {
                case .write:
                    Section("What's on your mind?") {
                        TextEditor(text: $text)
                            .frame(minHeight: 180)
                    }
                case .speak:
                    Section {
                        SpeakControls(recorder: recorder, onStart: { textBeforeRecording = text })
                        TextEditor(text: $text)
                            .frame(minHeight: 140)
                            .disabled(recorder.isRecording)
                    } header: {
                        Text("Say it out loud")
                    } footer: {
                        Text("Your words are transcribed on your phone. You can fix any mistakes after you stop.")
                    }
                case .draw:
                    Section("Draw it") {
                        DrawingCanvas(drawing: $drawing)
                            .frame(height: 320)
                            .listRowInsets(EdgeInsets())
                        Button("Clear", role: .destructive) { drawing = PKDrawing() }
                            .disabled(drawing.strokes.isEmpty)
                    }
                }

                Section {
                    LoopPicker(selection: $loop)
                }

                Section {
                    Button("Save entry", action: save)
                        .frame(maxWidth: .infinity)
                        .disabled(!canSave)
                }
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .themedBackground()
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .onChange(of: recorder.transcript) { _, spoken in
                text = textBeforeRecording.isEmpty ? spoken : textBeforeRecording + " " + spoken
            }
            .onChange(of: kind) { _, _ in
                if recorder.isRecording { recorder.stop() }
            }
            .sheet(item: $savedEntry) { entry in
                ReframePromptView(entry: entry)
            }
        }
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
        try? context.save()

        // Reset the form, then offer the reframe step.
        text = ""
        textBeforeRecording = ""
        drawing = PKDrawing()
        loop = nil
        savedEntry = entry
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
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(recorder.isRecording ? AnyShapeStyle(Color.red.opacity(0.85)) : AnyShapeStyle(.tint)))
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
        .padding(.vertical, 8)
    }
}

/// Shown right after saving: reframe now or skip. After a reframe,
/// it shows one of your past wins, to counter the habit of discounting them.
struct ReframePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Theme.storageKey) private var theme: Theme = .sage
    let entry: Entry

    private enum Step { case ask, reframe, win }
    @State private var step: Step = .ask

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .ask:
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text("Saved.")
                            .font(.title2.bold())
                        Text("Getting it out counts. Want to look at it from another angle?")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Reframe this thought") { step = .reframe }
                            .buttonStyle(.borderedProminent)
                        Button("Not today") { dismiss() }
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background.ignoresSafeArea())
                case .reframe:
                    ReframeView(entry: entry, onDone: { step = .win })
                case .win:
                    WinReminderView(onDone: { dismiss() })
                }
            }
        }
        .presentationDetents(step == .ask ? [.medium] : [.large])
    }
}

/// "Remember this?" One random past win, shown after a reframe.
struct WinReminderView: View {
    @Query private var wins: [Win]
    @AppStorage(Theme.storageKey) private var theme: Theme = .sage
    let onDone: () -> Void

    /// Picked once when the view appears, so it doesn't change on every redraw.
    @State private var win: Win?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            if let win {
                Text("Remember this?")
                    .font(.title2.bold())
                VStack(spacing: 8) {
                    Text(win.text)
                        .font(.title3)
                    if !win.meaning.isEmpty {
                        Text(win.meaning)
                            .foregroundStyle(.secondary)
                    }
                    Text(win.createdAt, format: .dateTime.month().day())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                Text("One hard moment doesn't erase this. Both are true.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nice work.")
                    .font(.title2.bold())
                Text("Next time something goes right, even something small, log it in Wins. You'll see it here after a reframe.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .onAppear { win = wins.randomElement() }
    }
}
