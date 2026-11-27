import SwiftUI
import SwiftData

/// Common values to start from in the welcome tour. Pick any, or name your own.
/// They become your values in Anchors and live inside the orb.
struct ValueChooser: View {
    @Binding var picked: Set<String>
    @State private var draft = ""

    static let starters = ["Curiosity", "Kindness", "Connection", "Growth", "Honesty", "Courage",
                           "Creativity", "Rest", "Family", "Independence", "Health", "Learning"]

    /// Starters first, then any you named yourself.
    private var all: [String] {
        Self.starters + picked.filter { !Self.starters.contains($0) }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(all, id: \.self) { name in
                    let on = picked.contains(name)
                    Button {
                        if on { picked.remove(name) } else { picked.insert(name) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            Text(name)
                                .font(.subheadline)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(on ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(Paper.card),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            HStack {
                TextField("Or name your own", text: $draft)
                    .onSubmit(addDraft)
                Button("Add", action: addDraft)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .sensoryFeedback(.selection, trigger: picked.count)
    }

    private func addDraft() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Keyboard.hide()
        picked.insert(name)
        draft = ""
    }

    /// Adds the picked values, skipping any you already have (by name, ignoring case).
    static func add(_ names: Set<String>, existing: [PersonalValue], to context: ModelContext) {
        let have = Set(existing.map { $0.name.lowercased() })
        for name in names.sorted() where !have.contains(name.lowercased()) {
            context.insert(PersonalValue(name: name))
        }
    }
}
