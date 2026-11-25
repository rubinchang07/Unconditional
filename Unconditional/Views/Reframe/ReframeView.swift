import SwiftUI
import SwiftData

/// CBT thought record for one entry: trigger, core belief, evidence for and against,
/// kinder read, small step.
/// Works for a new reframe or editing an existing one.
struct ReframeView: View {
    @Environment(\.modelContext) private var context
    let entry: Entry
    var onDone: () -> Void = {}

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

    var body: some View {
        Form {
            Section {
                RatingSlider(title: "How distressed do you feel?", value: $distressBefore,
                             lowLabel: "Calm", highLabel: "Overwhelmed")
                RatingSlider(title: "How much do you believe the thought?", value: $beliefBefore,
                             range: 0...100, step: 5, lowLabel: "Not at all", highLabel: "Completely",
                             valueText: { "\(Int($0))%" })
                if distressBefore >= 7 {
                    Button("That's a lot. Breathe for a minute first?", systemImage: "wind") { showBreathing = true }
                }
            } header: {
                Text("Right now")
            } footer: {
                Text("Somewhere in between is normal. There's no right number.")
            }

            Section {
                TextField("e.g. I couldn't solve a LeetCode medium", text: $trigger, axis: .vertical)
            } header: {
                Text("What happened?")
            } footer: {
                Text("Just the facts, as a camera would see them.")
            }

            Section {
                TextField("What did it seem to prove about you?", text: $coreBelief, axis: .vertical)
            } header: {
                Text("The belief underneath")
            }

            Section {
                TextField("What makes it feel true?", text: $evidenceFor, axis: .vertical)
            } header: {
                Text("Evidence for")
            }

            Section {
                TextField("What doesn't fit? Past wins, things you've handled, what others see", text: $evidenceAgainst, axis: .vertical)
            } header: {
                Text("Evidence against")
            } footer: {
                Text("Treat the belief like a hypothesis, not a fact. Feelings count as data, but not as proof.")
            }

            Section {
                TextField("What would you tell a friend in this spot?", text: $kinderRead, axis: .vertical)
            } header: {
                Text("A kinder, more accurate read")
            } footer: {
                Text("Not forced positivity. Ask: is this evidence about my worth, or about one hard moment?")
            }

            Section {
                TextField("Something you could do in 10 minutes", text: $smallStep, axis: .vertical)
            } header: {
                Text("One small step")
            }

            Section {
                RatingSlider(title: "How distressed do you feel now?", value: $distressAfter,
                             lowLabel: "Calm", highLabel: "Overwhelmed")
                RatingSlider(title: "How much do you believe it now?", value: $beliefAfter,
                             range: 0...100, step: 5, lowLabel: "Not at all", highLabel: "Completely",
                             valueText: { "\(Int($0))%" })
            } header: {
                Text("After looking at it")
            } footer: {
                Text("Even a small shift counts. A thought can go from 90% to 70% and that's real progress.")
            }
        }
        .navigationTitle("Reframe")
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .onAppear(perform: load)
        .onChange(of: distressBefore) { old, new in
            // Keep "after" following "before" until you've looked at the thought.
            if distressAfter == old { distressAfter = new }
        }
        .onChange(of: beliefBefore) { old, new in
            if beliefAfter == old { beliefAfter = new }
        }
        .sheet(isPresented: $showBreathing) { BreathingView() }
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
        try? context.save()
        onDone()
    }
}
