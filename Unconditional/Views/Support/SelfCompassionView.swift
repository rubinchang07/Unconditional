import SwiftUI
import SwiftData

/// A short self-compassion break, based on Kristin Neff's three parts:
/// noticing it's hard, remembering you're not alone, and offering yourself kindness.
struct SelfCompassionView: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: Entry
    var onDone: () -> Void = {}

    var body: some View {
        Form {
            Section {
                Text("No fixing needed here. Just noticing, and being on your own side for a minute.")
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("e.g. Feeling behind everyone is really painful right now", text: $entry.compassionHard, axis: .vertical)
            } header: {
                Text("1. This is hard")
            } footer: {
                Text("Name it without judging it. It can be a little hard or very hard.")
            }

            Section {
                TextField("e.g. Lots of people my age feel unsure about their path", text: $entry.compassionShared, axis: .vertical)
            } header: {
                Text("2. Others feel this too")
            } footer: {
                Text("Struggling is part of being human, not proof something is wrong with you.")
            }

            Section {
                TextField("e.g. Rest tonight, and one small step tomorrow", text: $entry.compassionNeed, axis: .vertical)
            } header: {
                Text("3. What do I need right now?")
            } footer: {
                Text("What would you offer a friend feeling this way? You can offer it to yourself too.")
            }
        }
        .navigationTitle("Self-compassion")
        .navigationBarTitleDisplayMode(.inline)
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    try? context.save()
                    onDone()
                }
            }
        }
    }
}
