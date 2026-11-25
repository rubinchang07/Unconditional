import SwiftUI
import SwiftData

/// A short CBT reframe in three steps. The fuller thought record (what happened,
/// evidence for and against, a small step) is tucked under "Go deeper".
/// Works for a new reframe or editing an existing one.
struct ReframeView: View {
    @Environment(\.modelContext) private var context
    let entry: Entry
    var onDone: () -> Void = {}
    /// When set, the last step offers a self-compassion break.
    var onCompassion: (() -> Void)? = nil

    @State private var trigger = ""
    @State private var coreBelief = ""
    @State private var evidenceFor = ""
    @State private var evidenceAgainst = ""
    @State private var kinderRead = ""
    @State private var smallStep = ""
    @State private var distressBefore = 5.0
    @State private var distressAfter = 5.0
    @State private var beliefBefore = 70.0
    @State private var beliefAfter = 70.0
    @State private var showBreathing = false
    @State private var saveFailed = false

    /// Three short steps: the thought, another way to see it, and how it feels now.
    private enum Step: Int, CaseIterable { case thought, another, now }
    @State private var step: Step = .thought
    @State private var goDeeper = false

    var body: some View {
        VStack(spacing: 0) {
            StepDots(count: Step.allCases.count, current: step.rawValue)
                .padding(.top, 8)

            Form {
                switch step {
                case .thought: thoughtStep
                case .another: anotherStep
                case .now: nowStep
                }
            }
            .scrollContentBackground(.hidden)

            HStack {
                if step != .thought {
                    Button("Back") { go(-1) }
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 70, minHeight: 44)
                }
                Spacer()
                if step == .now {
                    Button("Save", action: save).buttonStyle(.paper).frame(maxWidth: 200)
                } else {
                    Button("Next") { go(1) }.buttonStyle(.paper).frame(maxWidth: 200)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .navigationTitle("reframe")
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: distressBefore) { old, new in
            // Keep "after" following "before" until you've looked at the thought.
            if distressAfter == old { distressAfter = new }
        }
        .onChange(of: beliefBefore) { old, new in
            if beliefAfter == old { beliefAfter = new }
        }
        .sheet(isPresented: $showBreathing) { BreathingView() }
        .alert("couldn't save just now", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Everything you wrote is still here. Try again in a moment.")
        }
    }

    // MARK: - Step 1: the thought

    @ViewBuilder
    private var thoughtStep: some View {
        Section {
            TextField("What's the thought?", text: $coreBelief, axis: .vertical)
                .font(.system(.body, design: .serif))
        } header: {
            Text("The thought")
        }
        Section {
            RatingSlider(title: "How much do you believe it?", value: $beliefBefore,
                         range: 0...100, step: 5, lowLabel: "Not at all", highLabel: "Completely",
                         valueText: { "\(Int($0))%" })
            RatingSlider(title: "How distressed do you feel?", value: $distressBefore,
                         lowLabel: "Calm", highLabel: "Overwhelmed")
            if distressBefore >= 7 {
                Button("That's a lot. Breathe for a minute first?", systemImage: "wind") { showBreathing = true }
            }
        } footer: {
            Text("Somewhere in between is normal. There's no right number.")
        }
    }

    // MARK: - Step 2: another way to see it

    @ViewBuilder
    private var anotherStep: some View {
        Section {
            TextField("What would you tell a friend who thought this?", text: $kinderRead, axis: .vertical)
                .lineLimit(3...8)
        } header: {
            Text("Another way to see it")
        } footer: {
            Text("Not forced positivity. Just something kinder and a little more accurate.")
        }
        Section {
            DisclosureGroup("Go deeper", isExpanded: $goDeeper) {
                TextField("What happened, as a camera would see it", text: $trigger, axis: .vertical)
                TextField("What makes the thought feel true?", text: $evidenceFor, axis: .vertical)
                TextField("What doesn't fit it?", text: $evidenceAgainst, axis: .vertical)
                TextField("One small step, under 10 minutes", text: $smallStep, axis: .vertical)
            }
        } footer: {
            if goDeeper {
                Text("Treat the thought like a guess, not a fact. Feelings count as information, not proof.")
            }
        }
    }

    // MARK: - Step 3: now

    @ViewBuilder
    private var nowStep: some View {
        Section {
            DistressOrbs(before: distressBefore, after: distressAfter, maxSize: 100)
            RatingSlider(title: "How distressed do you feel now?", value: $distressAfter,
                         lowLabel: "Calm", highLabel: "Overwhelmed")
            RatingSlider(title: "How much do you believe it now?", value: $beliefAfter,
                         range: 0...100, step: 5, lowLabel: "Not at all", highLabel: "Completely",
                         valueText: { "\(Int($0))%" })
        } header: {
            Text("After looking at it")
        } footer: {
            Text("Even a small shift counts. So does no shift at all.")
        }
        if let onCompassion {
            Section {
                Button("Add a self-compassion break", systemImage: "heart") {
                    if persist() { onCompassion() }
                }
            } footer: {
                Text("Optional. For when it needs kindness more than logic.")
            }
        }
    }

    private func go(_ offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        withAnimation(.calm) { step = next }
    }

    private func load() {
        if let existing = entry.reframe {
            trigger = existing.trigger
            coreBelief = existing.coreBelief
            evidenceFor = existing.evidenceFor
            evidenceAgainst = existing.evidenceAgainst
            kinderRead = existing.kinderRead
            smallStep = existing.smallStep
            distressBefore = existing.distressBefore
            distressAfter = existing.distressAfter
            beliefBefore = existing.beliefBefore
            beliefAfter = existing.beliefAfter
        } else {
            // Start from the loop's core belief, so you can see it written down and question it.
            coreBelief = entry.loop?.coreBelief ?? ""
        }
    }

    private func save() {
        if persist() { onDone() }
    }

    /// Saves the reframe. Returns false (and says so gently) if it couldn't,
    /// so you stay on this screen with everything you wrote.
    @discardableResult
    private func persist() -> Bool {
        let reframe = entry.reframe ?? Reframe()
        reframe.trigger = trigger
        reframe.coreBelief = coreBelief
        reframe.evidenceFor = evidenceFor
        reframe.evidenceAgainst = evidenceAgainst
        reframe.kinderRead = kinderRead
        reframe.smallStep = smallStep
        reframe.distressBefore = distressBefore
        reframe.distressAfter = distressAfter
        reframe.beliefBefore = beliefBefore
        reframe.beliefAfter = beliefAfter
        if entry.reframe == nil {
            context.insert(reframe)
            entry.reframe = reframe
        }
        do {
            try context.save()
            return true
        } catch {
            saveFailed = true
            return false
        }
    }
}
