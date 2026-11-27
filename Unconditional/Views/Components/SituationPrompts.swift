import SwiftUI

/// Optional starting points for common moments, hard and good side by side,
/// since a check-in can be either. Tapping one only fills in a few gentle
/// questions in the journal. It's still an ordinary entry.
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
        // Replaces the separate career check-in: same questions, now an ordinary entry.
        Situation(title: "About work or school", symbol: "briefcase",
                  prompt: "What I was doing (studying, applying, an interview, a setback):\n\nWhat I learned:\n\nWhat was interesting, even a little:\n\nHow much I enjoyed the work itself, apart from how it went:\n\n"),
        Situation(title: "A hard study session", symbol: "book",
                  prompt: "What I was working on:\n\nWhere it got hard:\n\nWhat I learned anyway, even a little:\n\n"),
        Situation(title: "Feeling behind", symbol: "hourglass",
                  prompt: "Who or what I'm comparing myself to:\n\nWhat I can't see about their path:\n\nOne thing I've done that past me would be glad about:\n\n"),
        Situation(title: "A relationship worry", symbol: "heart",
                  prompt: "What's on my mind:\n\nWhat I'm afraid it means:\n\nWhat I actually know for sure:\n\n"),
        Situation(title: "Not sure what's next", symbol: "signpost.right",
                  prompt: "The choice in front of me:\n\nWhat I'm afraid of getting wrong:\n\nWhat I'd do if I didn't need to be certain:\n\n"),
    ]

    static let goodOnes: [Situation] = [
        Situation(title: "A small win", symbol: "star",
                  prompt: "What went right:\n\nWhat I did to help it happen:\n\n"),
        Situation(title: "Someone was kind", symbol: "heart",
                  prompt: "Who, and what they did:\n\nHow it felt:\n\n"),
        Situation(title: "A calm moment", symbol: "leaf",
                  prompt: "Where I was:\n\nWhat made it feel calm:\n\n"),
        Situation(title: "I learned something", symbol: "lightbulb",
                  prompt: "What I learned:\n\nWhat made it interesting:\n\n"),
        Situation(title: "I'm proud that", symbol: "sparkles",
                  prompt: "I'm proud that\n\nIt matters to me because\n\n"),
    ]

    /// Hard and good moments taken in turn, so neither kind is tucked at the end.
    static var mixed: [Situation] {
        var result: [Situation] = []
        for i in 0..<max(all.count, goodOnes.count) {
            if i < all.count { result.append(all[i]) }
            if i < goodOnes.count { result.append(goodOnes[i]) }
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.mixed) { situation in
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
