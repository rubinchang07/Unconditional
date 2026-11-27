import SwiftUI
import SwiftData

/// A short reframe in two quiet screens, one thing to write on each:
/// 1. heart: your check-in, shown back to you, and how heavy it feels
/// 2. head: step back and describe it as objectively as you can, and how heavy it is seen that way
/// Afterwards (in `HeadAndHeart`) the two are shown together as waves for the first time.
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
    @State private var headLight = 0.5
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
                .transition(.calmSwap())
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
            Label("In your heart, how does it feel?", systemImage: "heart")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .softCase()
            // You already wrote it in the check-in, so it's shown, not asked again.
            if entry.kind.isText, !entry.text.isEmpty {
                Text("“\(entry.text)”")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 16)
            }
            heaviness("How heavy does the situation feel?", value: $distressBefore)
            if distressBefore >= 7 {
                Button("That's a lot. Breathe for a minute first?", systemImage: "wind") { showBreathing = true }
                    .font(.subheadline)
            }
        }
    }

    // MARK: - 2. Another way to see it

    private var anotherStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("Now step back. Looking at it logically, how would you describe the situation?", systemImage: "brain.head.profile")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .softCase()
            TextField("Just the facts, as an outsider might see them", text: $kinderRead, axis: .vertical)
                .font(.system(.title3, design: .serif))
                .lineLimit(3...8)
                .focused($writing)
                .paperCard(padding: 16)
            VStack(alignment: .leading, spacing: 6) {
                Text("Seen this way, how heavy is the situation?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $headLight, in: 0...1)
                    .accessibilityLabel("Seen this way, how heavy is the situation")
                    .accessibilityValue(headLight < 0.5 ? "heavier" : "lighter")
                HStack {
                    Text("heavy")
                    Spacer()
                    Text("light")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// One heavy-to-light slider, no numbers on screen. Heavy on the left and light on
    /// the right, the same way round as the head slider, so nothing has to be flipped
    /// in your head between screens. The value is still stored as heaviness, 0 to 10.
    private func heaviness(_ title: String, value: Binding<Double>) -> some View {
        let lightness = Binding<Double>(get: { 10 - value.wrappedValue }, set: { value.wrappedValue = 10 - $0 })
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Slider(value: lightness, in: 0...10)
                .accessibilityLabel(title)
                .accessibilityValue(value.wrappedValue > 5 ? "heavier" : "lighter")
            HStack {
                Text("heavy")
                Spacer()
                Text("light")
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
            if existing.headLight >= 0 { headLight = existing.headLight }
        } else if let lightness = entry.lightness {
            // Start the heart where you left the check-in slider, so it's a glance, not a repeat.
            // Move it only if the feeling shifted as you wrote.
            distressBefore = 10 * (1 - min(max(lightness, 0), 1))
            distressAfter = distressBefore
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
        // Heaviness is asked once now, on the heart screen; head and heart are compared instead.
        reframe.distressAfter = reframe.hasHeadAndHeart || entry.reframe == nil ? distressBefore : distressAfter
        reframe.beliefBefore = beliefBefore
        reframe.beliefAfter = beliefAfter
        reframe.headLight = headLight
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
