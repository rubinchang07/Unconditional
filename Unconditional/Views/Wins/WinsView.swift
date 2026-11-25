import SwiftUI
import SwiftData

/// "Anchors": the things that hold your worth steady.
/// Wins (what you did) and Values (what you stand for), side by side.
struct WinsView: View {
    private enum Page: String, CaseIterable { case wins = "Wins", values = "Values" }
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
                }
            }
            .background(ThemeBackground())
            .navigationTitle(page.rawValue)
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
                    }
                    .onDelete { offsets in
                        offsets.forEach { context.delete(wins[$0]) }
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
