import SwiftUI
import SwiftData

/// "I'm spiraling." A quick way to interrupt a loop in one or two taps,
/// without writing a full entry.
///
/// Tap the thought closest to yours, read a gentler perspective, then pick
/// one of three: let it be, park it for later, or breathe.
/// Not every thought needs to be analyzed. Acknowledging it is enough.
struct ThoughtResetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    @Query(sort: \ResetThought.sortOrder) private var thoughts: [ResetThought]
    @Query(filter: #Predicate<ParkedThought> { $0.reviewedAt == nil }) private var parked: [ParkedThought]
    @Query private var laughs: [Laugh]

    private enum Step: Equatable { case pick, perspective, closing(String) }
    /// How the closing orb behaves: the thought drifts into it, or a small orb pinches off.
    private enum Closing { case plain, absorb(String), park }
    @State private var closing: Closing = .plain
    @State private var absorbed = false
    @State private var ripple = 0
    @State private var step: Step = .pick

    @State private var chosen: ResetThought?
    @State private var customThought = ""
    @State private var editingPerspective = false
    @State private var showBreathing = false
    @State private var showReview = false
    /// After a reset, one thing that made you laugh, if you asked for something lighter.
    @State private var lighter: Laugh?

    /// The perspective for "Something else": no argument with the thought, just room around it.
    private let generalPerspective = "This thought is here, and it's heavy. You don't have to argue with it or obey it. You can notice it, and choose your next step."

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .pick: pickStep
                case .perspective: perspectiveStep
                case .closing(let message): closingStep(message)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ThemeBackground())
            .navigationTitle("thought reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if step == .perspective {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { go(.pick) }
                    }
                }
            }
            .keyboardDoneButton()
            .sheet(isPresented: $showBreathing) { BreathingView() }

            .sheet(isPresented: $showReview) {
                NavigationStack { ParkedReviewView() }
            }
            .sheet(isPresented: $editingPerspective) {
                if let chosen {
                    NavigationStack { PerspectiveEditor(thought: chosen) }
                }
            }
        }
    }

    // MARK: - Step 1: pick the closest thought

    private var pickStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                PaperHeading(title: "What's weighing on you?",
                             subtitle: "Tap the thought that feels closest. You don't have to explain everything.")
                    .padding(.vertical, 8)

                ForEach(thoughts) { thought in
                    Button {
                        chosen = thought
                        customThought = ""
                        go(.perspective)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thought.text)
                                .font(.system(.body, design: .serif))
                            if let loop = thought.loop {
                                Text(loop.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .paperCard(padding: 16)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Something else")
                        .font(.system(.body, design: .serif))
                    TextField("In a few words…", text: $customThought)
                        .onSubmit(useCustomThought)
                    if !customThought.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Continue", action: useCustomThought)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .paperCard(padding: 16)

                if !parked.isEmpty {
                    Button {
                        showReview = true
                    } label: {
                        Label("\(parked.count) parked thought\(parked.count == 1 ? "" : "s") waiting for Sunday",
                              systemImage: "tray")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Step 2: a different perspective, and what to do with it

    private var perspectiveStep: some View {
        let thoughtText = chosen?.text ?? customThought
        let perspective = chosen?.perspective ?? generalPerspective

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("“\(thoughtText)”")
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text((chosen?.loop?.name ?? "Another angle").uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(perspective)
                        .font(.system(.title3, design: .serif))
                        .lineSpacing(4)
                    if chosen != nil {
                        Button("Rewrite in my own words", systemImage: "pencil") { editingPerspective = true }
                            .font(.footnote)
                    }
                }
                .paperCard()

                // The main action is the gentlest one: just letting it be.
                Button("Okay. I can let it be here.") {
                    closing = .absorb(thoughtText)
                    finish("Noticed. You don't have to solve it right now.")
                }
                .buttonStyle(.paper)

                HStack(spacing: 12) {
                    choice("Park it for later", symbol: "tray.and.arrow.down") {
                        context.insert(ParkedThought(text: thoughtText))
                        try? context.save()
                        ReminderScheduler.scheduleSundayReview()
                        closing = .park
                        finish("Parked. You can look at it calmly later, not in the middle of a spiral.")
                    }
                    choice("Breathe", symbol: "wind") { showBreathing = true }
                }

                Text("Every option is optional. Doing none of them is fine too.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// A square card with an icon, so the two extra choices read at a glance.
    private func choice(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .paperCard(padding: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: a calm close

    private func closingStep(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                if case .park = closing {
                    PinchOffOrb(palette: orbPalette)
                        .frame(width: 160, height: 160)
                } else {
                    OrbView(palette: orbPalette, state: .settling, ripple: ripple)
                        .frame(width: 140, height: 140)
                }
                // "Let it be": the thought softens and drifts into the orb, which ripples once.
                if case .absorb(let thought) = closing {
                    Text("“\(thought)”")
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .scaleEffect(absorbed ? 0.2 : 1)
                        .blur(radius: absorbed ? 8 : 0)
                        .opacity(absorbed ? 0 : 1)
                        .offset(y: absorbed ? 0 : -150)
                        .task {
                            withAnimation(.easeIn(duration: 1.4)) { absorbed = true }
                            try? await Task.sleep(for: .seconds(1.25))
                            ripple += 1
                        }
                }
            }
            Text(message)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
            // Something you once kept because it made you laugh, only if you ask.
            if let lighter {
                LaughCard(laugh: lighter)
                    .paperCard(padding: 14)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if !laughs.isEmpty {
                Button("Want something lighter?", systemImage: "face.smiling") {
                    withAnimation(.calm) { lighter = laughs.randomElement() }
                }
                .font(.subheadline)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.paper)
            Button("Reset another thought") {
                closing = .plain
                absorbed = false
                lighter = nil
                chosen = nil
                customThought = ""
                go(.pick)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    private func go(_ newStep: Step) {
        withAnimation(.easeInOut(duration: 0.3)) { step = newStep }
    }

    private func useCustomThought() {
        guard !customThought.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        chosen = nil
        go(.perspective)
    }

    private func finish(_ message: String) {
        go(.closing(message))
    }
}

/// Rewrite a perspective so it sounds like you.
private struct PerspectiveEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var thought: ResetThought
    /// What it said before you started, so a real rewrite can be kept in Anchors.
    @State private var original = ""

    var body: some View {
        Form {
            Section("The thought") {
                TextField("Thought", text: $thought.text, axis: .vertical)
            }
            Section {
                TextField("Perspective", text: $thought.perspective, axis: .vertical)
            } header: {
                Text("A different perspective")
            } footer: {
                Text("Write what you'd want to hear in that moment. It doesn't have to be positive, just kind and fair. Your rewrite is also kept in Anchors.")
            }
        }
        .onAppear { if original.isEmpty { original = thought.perspective } }
        .navigationTitle("edit")
        .navigationBarTitleDisplayMode(.inline)
        .themedBackground()
        .paperList()
        .keyboardDoneButton()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    keepRewrite()
                    dismiss()
                }
            }
        }
    }

    /// A perspective you rewrote in your own words becomes one of your
    /// "words to come back to" in Anchors.
    private func keepRewrite() {
        let text = thought.perspective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != original else { return }
        let existing = (try? context.fetch(FetchDescriptor<SavedReminder>())) ?? []
        guard !existing.contains(where: { $0.text == text }) else { return }
        context.insert(SavedReminder(text: text))
        try? context.save()
    }
}
