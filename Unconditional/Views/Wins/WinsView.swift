import SwiftUI
import SwiftData

/// "Anchors": the things that hold your worth steady.
/// Wins (what you did), Values (what you stand for), and Reminders (what you want to hear).
struct WinsView: View {
    private enum Page: String, CaseIterable { case wins = "Wins", values = "Values", reminders = "Reminders" }
    @State private var page: Page = .wins

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Show", selection: $page) {
                    ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                switch page {
                case .wins: WinsList()
                case .values: ValuesList()
                case .reminders: RemindersList()
                }
            }
            .background(ThemeBackground())
            .navigationTitle(page.rawValue.lowercased())
            .keyboardDoneButton()
        }
    }
}

/// Quick-add wins plus the running list. Small ones count: that's the point.
struct WinsList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Win.createdAt, order: .reverse) private var wins: [Win]

    @State private var newWin = ""
    @State private var meaning = ""
    @State private var effortToOutcome = 0.5
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                TextField("What went right today, even a little?", text: $newWin, axis: .vertical)
                    .focused($focused)
                TextField("What does this say about you? (optional)", text: $meaning, axis: .vertical)
                    .font(.callout)
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: $effortToOutcome, in: 0...1)
                        .accessibilityLabel("Effort or outcome")
                        .accessibilityValue(Win.effortLabel(for: effortToOutcome))
                    HStack {
                        Text("I tried")
                        Spacer()
                        Text("It worked out")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Button("Add win", action: add)
                    .disabled(newWin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("You tend to discount successes. Logging them is a way of keeping score fairly. Effort counts, even when the outcome isn't there yet.")
            }

            if wins.isEmpty {
                GentleEmpty(symbol: "star", title: "Your wins will gather here",
                            message: "Small ones count. So does trying. Nothing has to be impressive to belong here.")
                    .listRowBackground(Color.clear)
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
                            HStack(spacing: 6) {
                                Text(win.createdAt, format: .dateTime.month().day())
                                Text("·")
                                Text(win.effortLabel)
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                        .gentleRemove { context.delete(win) }
                    }
                }
            }
        }
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
    }

    private func add() {
        context.insert(Win(text: newWin.trimmingCharacters(in: .whitespacesAndNewlines),
                           meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
                           effortToOutcome: effortToOutcome))
        try? context.save()
        newWin = ""
        meaning = ""
        effortToOutcome = 0.5
        focused = false
    }
}

/// Your encouragement library: short things you want to see when it's hard.
struct RemindersList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedReminder.createdAt, order: .reverse) private var reminders: [SavedReminder]
    @State private var newReminder = ""

    var body: some View {
        List {
            Section {
                TextField("e.g. I can feel uncertain and still take one step", text: $newReminder, axis: .vertical)
                Button("Add reminder") {
                    context.insert(SavedReminder(text: newReminder.trimmingCharacters(in: .whitespacesAndNewlines)))
                    try? context.save()
                    newReminder = ""
                }
                .disabled(newReminder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Write them in your own words, or save one from Thought Reset. They can show up after a reframe.")
            }

            if reminders.isEmpty {
                GentleEmpty(symbol: "bookmark", title: "Words for hard moments",
                            message: "Things you'd want to hear when it's a lot. Write your own, or save one from a thought reset.")
                    .listRowBackground(Color.clear)
            }

            if !reminders.isEmpty {
                Section("Yours") {
                    ForEach(reminders) { reminder in
                        Text(reminder.text)
                            .font(.system(.body, design: .serif))
                            .padding(.vertical, 4)
                            .gentleRemove { context.delete(reminder) }
                    }
                }
            }
        }
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
    }
}
