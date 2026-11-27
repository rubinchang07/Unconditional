import SwiftUI
import SwiftData

/// A short CBT reframe in two quiet screens, one thing to write on each:
/// 1. the thought, and how heavy it feels
/// 2. what you'd tell a friend, and how heavy it feels now
/// Older reframes keep anything they had (evidence, a small step), untouched.
struct ReframeView: View {
    @Environment(\.modelContext) private var context
    let entry: Entry
    var onDone: () -> Void = {}
    /// Kept so callers don't change. The self-compassion break isn't offered here
    /// any more, to keep the reframe short.
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

    private enum Step: Int, CaseIterable { case thought, another }
    @State private var step: Step = .thought
    @FocusState private var writing: Bool

    var body: some View {
        VStack(spacing: 20) {
            StepDots(count: Step.allCases.count, current: step.rawValue)
                .padding(.top, 8)

            ScrollView {
                Group {
                    switch step {
                    case .thought: thoughtStep
                    case .another: anotherStep
                    }
                }
                .id(step)
                .transition(.opacity)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            HStack {
                if step != .thought {
                    Button("Back") { go(-1) }
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 70, minHeight: 44)
                }
                Spacer()
                if step == .another {
                    Button("Save", action: save).buttonStyle(.paper).frame(maxWidth: 200)
                } else {
                    Button("Next") { go(1) }.buttonStyle(.paper).frame(maxWidth: 200)
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .navigationTitle("reframe")
        .themedBackground()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: distressBefore) { old, new in
            // "Now" starts where "before" was, until you move it.
            if distressAfter == old { distressAfter = new }
        }
        .sheet(isPresented: $showBreathing) { BreathingView() }
        .alert("couldn't save just now", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Everything you wrote is still here. Try again in a moment.")
        }
    }

    // MARK: - 1. The thought

    private var thoughtStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("What's the thought?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .softCase()
            TextField("In your own words", text: $coreBelief, axis: .vertical)
                .font(.system(.title3, design: .serif))
                .lineLimit(2...6)
                .focused($writing)
                .paperCard(padding: 16)
            heaviness("How heavy does it feel?", value: $distressBefore)
            if distressBefore >= 7 {
                Button("That's a lot. Breathe for a minute first?", systemImage: "wind") { showBreathing = true }
                    .font(.subheadline)
            }
        }
    }

    // MARK: - 2. Another way to see it

    private var anotherStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("What would you tell a friend?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .softCase()
            if !coreBelief.isEmpty {
                Text("“\(coreBelief)”")
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            TextField("Something kinder, and a little more accurate", text: $kinderRead, axis: .vertical)
                .font(.system(.title3, design: .serif))
                .lineLimit(3...8)
                .focused($writing)
                .paperCard(padding: 16)
            heaviness("And now?", value: $distressAfter)
        }
    }

    /// One heavy-to-light slider, no numbers on screen.
    private func heaviness(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Slider(value: value, in: 0...10)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(value.wrappedValue.rounded())) out of 10")
            HStack {
                Text("light")
                Spacer()
                Text("very heavy")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
