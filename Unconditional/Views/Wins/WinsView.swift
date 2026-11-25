import SwiftUI
import SwiftData

/// Quick-add wins plus the running list. Small ones count: that's the point.
struct WinsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Win.createdAt, order: .reverse) private var wins: [Win]

    @State private var newWin = ""
    @State private var meaning = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("What went right today, even a little?", text: $newWin, axis: .vertical)
                        .focused($focused)
                    TextField("What does this say about you? (optional)", text: $meaning, axis: .vertical)
                        .font(.callout)
                    Button("Add win", action: add)
                        .disabled(newWin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("You tend to discount successes. Logging them is a way of keeping score fairly.")
                }

                if !wins.isEmpty {
                    Section("\(wins.count) logged") {
                        ForEach(wins) { win in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(win.text)
                                if !win.meaning.isEmpty {
                                    Text(win.meaning)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                Text(win.createdAt, format: .dateTime.month().day())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(wins[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("Wins")
            .themedBackground()
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
        }
    }

    private func add() {
        context.insert(Win(text: newWin.trimmingCharacters(in: .whitespacesAndNewlines),
                           meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines)))
        try? context.save()
        newWin = ""
        meaning = ""
        focused = false
    }
}
