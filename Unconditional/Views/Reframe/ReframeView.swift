import SwiftUI
import SwiftData

/// CBT thought record for one entry: trigger, core belief, kinder read, small step.
/// Works for a new reframe or editing an existing one.
struct ReframeView: View {
    @Environment(\.modelContext) private var context
    let entry: Entry
    var onDone: () -> Void = {}

    @State private var trigger = ""
    @State private var coreBelief = ""
    @State private var kinderRead = ""
    @State private var smallStep = ""

    var body: some View {
        Form {
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
        }
        .navigationTitle("Reframe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        if let existing = entry.reframe {
            trigger = existing.trigger
            coreBelief = existing.coreBelief
            kinderRead = existing.kinderRead
            smallStep = existing.smallStep
        } else {
            // Start from the loop's core belief, so you can see it written down and question it.
            coreBelief = entry.loop?.coreBelief ?? ""
        }
    }

    private func save() {
        let reframe = entry.reframe ?? Reframe()
        reframe.trigger = trigger
        reframe.coreBelief = coreBelief
        reframe.kinderRead = kinderRead
        reframe.smallStep = smallStep
        if entry.reframe == nil {
            context.insert(reframe)
            entry.reframe = reframe
        }
        try? context.save()
        onDone()
    }
}
