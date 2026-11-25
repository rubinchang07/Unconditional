import SwiftUI

/// 5-4-3-2-1 grounding: notice 5 things you can see, 4 you can touch,
/// 3 you can hear, 2 you can smell, and 1 you can taste. Tap the orb for each
/// one you notice. It's a quick way out of your head and back into the room.
struct GroundingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage

    private struct Sense {
        let count: Int
        let verb: String
        let hint: String
    }

    private let senses = [
        Sense(count: 5, verb: "see", hint: "Look around slowly. Colors, shapes, light, anything at all."),
        Sense(count: 4, verb: "touch", hint: "Your clothes, the chair, the floor under your feet, your phone."),
        Sense(count: 3, verb: "hear", hint: "Near or far. Traffic, a fan, your own breathing."),
        Sense(count: 2, verb: "smell", hint: "Lean in close to something. Or remember two smells you like."),
        Sense(count: 1, verb: "taste", hint: "What's in your mouth right now, or a sip of something."),
    ]

    @State private var index = 0
    @State private var noticed = 0
    @State private var pulse = false
    @State private var finished = false
    /// The words fade out fully before the next sense's words fade in,
    /// so two lines never sit on top of each other.
    @State private var wordsShown = true
    @State private var changing = false

    private var sense: Sense { senses[min(index, senses.count - 1)] }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Group {
                if finished {
                    Text("you're here.")
                } else {
                    Text("\(sense.count) \(sense.count == 1 ? "thing" : "things") you can \(sense.verb)")
                }
            }
            .font(.system(.title, design: .serif).weight(.semibold))
            .multilineTextAlignment(.center)
            .opacity(wordsShown ? 1 : 0)

            // The orb draws itself without taking touches, so the circle here is what you tap.
            // Each thing you notice brings the orb a little more into focus,
            // like the room coming back. A new sense starts soft again.
            DispersingOrb(palette: palette, state: .resting, dispersed: finished)
                .frame(width: 240, height: 240)
                .blur(radius: finished ? 0 : 16 * (1 - Double(noticed) / Double(sense.count)))
                .animation(.easeInOut(duration: 0.6), value: noticed)
                .scaleEffect(pulse ? 1.08 : 1)
                .contentShape(Circle())
                .onTapGesture(perform: notice)
                .accessibilityElement()
                .accessibilityLabel("I noticed one")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, notice)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: noticed)

            if finished {
                Text("Your feet are on the floor, and this moment is the only one you have to be in.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                // One dot for each thing to notice; they fill as you tap the orb.
                HStack(spacing: 10) {
                    ForEach(0..<sense.count, id: \.self) { dot in
                        Circle()
                            .fill(dot < noticed ? AnyShapeStyle(.tint) : AnyShapeStyle(.tint.opacity(0.18)))
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("\(noticed) of \(sense.count)")
                .opacity(wordsShown ? 1 : 0)
                Text(sense.hint)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .opacity(wordsShown ? 1 : 0)
                Text("Tap the orb for each one you notice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            HStack {
                if !finished {
                    // Smell and taste can be hard to find. Skipping is fine.
                    Button("skip this one", action: next)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                Spacer()
                Button(finished ? "done" : "stop") { dismiss() }
                    .buttonStyle(.paper)
                    .frame(maxWidth: finished ? .infinity : 140)
            }
        }
        .padding(28)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .animation(.calm, value: finished)
    }

    private func notice() {
        guard !finished, !changing, noticed < sense.count else { return }
        noticed += 1
        withAnimation(.spring(duration: 0.25, bounce: 0.5)) { pulse = true }
        withAnimation(.spring(duration: 0.5).delay(0.2)) { pulse = false }
        if noticed == sense.count {
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                next()
            }
        }
    }

    private func next() {
        guard !changing else { return }
        changing = true
        Task {
            // Out, swap while nothing shows, then in.
            withAnimation(.easeOut(duration: 0.3)) { wordsShown = false }
            try? await Task.sleep(for: .milliseconds(320))
            noticed = 0
            if index + 1 < senses.count {
                index += 1
            } else {
                withAnimation(.calm) { finished = true }
            }
            withAnimation(.easeIn(duration: 0.4)) { wordsShown = true }
            changing = false
        }
    }
}
