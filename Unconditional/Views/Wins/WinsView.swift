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
    /// Two words you tap instead of a slider. Both, either, or neither.
    @State private var tried = false
    @State private var workedOut = false

    /// Still stored on the same spectrum, so older wins and Patterns keep working.
    private var effortToOutcome: Double {
        switch (tried, workedOut) {
        case (true, false): 0.1
        case (false, true): 0.9
        default: 0.5
        }
    }
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                TextField("What went right today, even a little?", text: $newWin, axis: .vertical)
                    .focused($focused)
                TextField("What does this say about you? (optional)", text: $meaning, axis: .vertical)
                    .font(.callout)
                HStack(spacing: 10) {
                    WordChip(title: "I tried", isOn: $tried)
                    WordChip(title: "It worked out", isOn: $workedOut)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
                Button("Add win", action: add)
                    .disabled(newWin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("You tend to discount successes. Logging them keeps the record fair. Effort counts, even when the outcome isn't there yet.")
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
                            .foregroundStyle(.secondary)
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
        tried = false
        workedOut = false
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
                TextField("For example: I can feel uncertain and still take one step", text: $newReminder, axis: .vertical)
                Button("Add reminder") {
                    context.insert(SavedReminder(text: newReminder.trimmingCharacters(in: .whitespacesAndNewlines)))
                    try? context.save()
                    newReminder = ""
                }
                .disabled(newReminder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Write them in your own words. They can show up after a reframe.")
            }

            if reminders.isEmpty {
                GentleEmpty(symbol: "bookmark", title: "Words for hard moments",
                            message: "Things you'd want to hear when it's a lot. Write them in your own words.")
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

/// A word you tap on or off. Softer than a slider for a quick note.
struct WordChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.secondary.opacity(0.08)), in: Capsule())
                .overlay(Capsule().strokeBorder(.tint.opacity(isOn ? 0.5 : 0), lineWidth: 1))
                .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
