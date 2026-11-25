import SwiftUI
import SwiftData
import PencilKit

/// Start of the daily flow: choose Write or Draw, get it out, tag the loop, save.
/// Saving offers the optional Reframe step.
struct TodayView: View {
    @Environment(\.modelContext) private var context

    @State private var kind: EntryKind = .write
    @State private var text = ""
    @State private var drawing = PKDrawing()
    @State private var loop: Loop?

    /// When set, the "reframe this?" sheet opens for that entry.
    @State private var savedEntry: Entry?

    private var canSave: Bool {
        kind == .write
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

                Section(kind == .write ? "What's on your mind?" : "Draw it") {
                    switch kind {
                    case .write:
                        TextEditor(text: $text)
                            .frame(minHeight: 180)
                    case .draw:
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
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .sheet(item: $savedEntry) { entry in
                ReframePromptView(entry: entry)
            }
        }
    }

    private func save() {
        let entry = Entry(
            kind: kind,
            text: kind == .write ? text : "",
            drawingData: kind == .draw ? drawing.dataRepresentation() : nil
        )
        // Insert first, then link relationships: SwiftData is happiest when both
        // sides of a relationship already belong to the same context.
        context.insert(entry)
        entry.loop = loop
        try? context.save()

        // Reset the form, then offer the reframe step.
        text = ""
        drawing = PKDrawing()
        loop = nil
        savedEntry = entry
    }
}

/// Shown right after saving: reframe now, or skip.
struct ReframePromptView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: Entry
    @State private var showReframe = false

    var body: some View {
        NavigationStack {
            if showReframe {
                ReframeView(entry: entry, onDone: { dismiss() })
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Saved.")
                        .font(.title2.bold())
                    Text("Writing it down counts. Want to look at it from another angle?")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Reframe this thought") { showReframe = true }
                        .buttonStyle(.borderedProminent)
                    Button("Not today") { dismiss() }
                }
                .padding(32)
            }
        }
        .presentationDetents(showReframe ? [.large] : [.medium])
    }
}
