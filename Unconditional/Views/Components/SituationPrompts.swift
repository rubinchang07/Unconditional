import SwiftUI

/// Optional starting points for common hard moments. Tapping one only fills in
/// a few gentle questions in the journal. It's still an ordinary entry.
struct SituationPrompts: View {
    @Binding var text: String

    struct Situation: Identifiable {
        let title: String
        let symbol: String
        let prompt: String
        var id: String { title }
    }

    static let all: [Situation] = [
        Situation(title: "A rejection", symbol: "envelope.open",
                  prompt: "What happened:\n\nWhat it felt like it said about me:\n\nWhat else it could mean:\n\n"),
        Situation(title: "A hard study session", symbol: "book",
                  prompt: "What I was working on:\n\nWhere it got hard:\n\nWhat I learned anyway, even a little:\n\n"),
        Situation(title: "Feeling behind", symbol: "hourglass",
                  prompt: "Who or what I'm comparing myself to:\n\nWhat I can't see about their path:\n\nOne thing I've done that past me would be glad about:\n\n"),
        Situation(title: "A relationship worry", symbol: "heart",
                  prompt: "What's on my mind:\n\nWhat I'm afraid it means:\n\nWhat I actually know for sure:\n\n"),
        Situation(title: "Not sure what's next", symbol: "signpost.right",
                  prompt: "The choice in front of me:\n\nWhat I'm afraid of getting wrong:\n\nWhat I'd do if I didn't need to be certain:\n\n"),
    ]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.all) { situation in
                    Button {
                        withAnimation(.calm) {
                            text = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? situation.prompt
                                : text + "\n\n" + situation.prompt
                        }
                    } label: {
                        Label(situation.title, systemImage: situation.symbol)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Paper.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(.tint.opacity(0.25)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Optional starting points")
    }
}
