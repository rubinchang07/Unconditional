import SwiftUI
import SwiftData

/// What matters to you, no matter how things turn out.
struct ValuesList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PersonalValue.createdAt) private var values: [PersonalValue]

    @State private var custom = ""

    private var unusedSuggestions: [String] {
        let taken = Set(values.map { $0.name.lowercased() })
        return PersonalValue.suggestions.filter { !taken.contains($0.lowercased()) }
    }

    var body: some View {
        List {
            Section {
                Text("Your worth doesn't wait on outcomes. Values are things you can live today, whether or not the job, the timeline, or the relationship has arrived.")
                    .foregroundStyle(.secondary)
            }

            if !values.isEmpty {
                Section("Yours") {
                    ForEach(values) { value in
                        NavigationLink {
                            ValueDetailView(value: value)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(value.name)
                                    .font(.system(.headline, design: .serif))
                                if !value.meaning.isEmpty {
                                    Text(value.meaning)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { context.delete(values[$0]) }
                    }
                }
            }

            Section {
                if !unusedSuggestions.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(unusedSuggestions, id: \.self) { name in
                                Button(name) { add(name) }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
                HStack {
                    TextField("Or write your own", text: $custom)
                        .onSubmit { add(custom) }
                    Button("Add") { add(custom) }
                        .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Add a value")
            } footer: {
                Text("Pick a few that feel like yours. You can tap one to describe what it means to you.")
            }
        }
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
    }

    private func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation { context.insert(PersonalValue(name: trimmed)) }
        try? context.save()
        custom = ""
    }
}

/// Describe a value and check in on how much you've lived it lately.
struct ValueDetailView: View {
    @Bindable var value: PersonalValue

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $value.name)
            }
            Section {
                TextField("e.g. Asking questions even when I feel behind", text: $value.meaning, axis: .vertical)
            } header: {
                Text("What it looks like for me")
            }
            Section {
                RatingSlider(title: "Lived it lately", value: $value.livedLately,
                             lowLabel: "Not much", highLabel: "A lot")
            } footer: {
                Text("A check-in, not a grade. Low just means it might be worth a small step this week.")
            }
        }
        .navigationTitle(value.name)
        .navigationBarTitleDisplayMode(.inline)
        .themedBackground()
        .paperList()
        .keyboardDoneButton()
    }
}
