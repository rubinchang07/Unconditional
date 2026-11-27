import SwiftUI
import SwiftData

/// The weekly review for parked thoughts. The point isn't to stop big changes,
/// it's to make them from a calm place instead of a spiral.
struct ParkedReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight
    @Query(filter: #Predicate<ParkedThought> { $0.reviewedAt == nil },
           sort: \ParkedThought.createdAt) private var waiting: [ParkedThought]
    @Query(filter: #Predicate<ParkedThought> { $0.reviewedAt != nil },
           sort: \ParkedThought.createdAt, order: .reverse) private var reviewed: [ParkedThought]
    @Query(sort: \CareerReflection.createdAt, order: .reverse) private var reflections: [CareerReflection]
    @Query(sort: \Reframe.createdAt, order: .reverse) private var reframes: [Reframe]
    @State private var revisiting: Reframe?

    /// One or two recent reframes worth a second look: a few days old, not looked at again yet.
    private var lookAgain: [Reframe] { ParkedReviewView.lookAgain(from: reframes) }

    static func lookAgain(from reframes: [Reframe], now: Date = .now) -> [Reframe] {
        let threeWeeks = now.addingTimeInterval(-21 * 86_400)
        return Array(reframes.filter { $0.canRevisit(now: now) && !$0.hasLater && $0.createdAt >= threeWeeks && $0.entry != nil }
            .prefix(2))
    }

    /// Things you learned or enjoyed in the last 7 days, to weigh alongside the doubts.
    private var thisWeek: [CareerReflection] {
        let weekAgo = Date.now.addingTimeInterval(-7 * 86_400)
        return reflections.filter { $0.createdAt >= weekAgo && !($0.learned.isEmpty && $0.interesting.isEmpty) }
    }

    var body: some View {
        List {
            if !waiting.isEmpty {
                Section {
                    // The cloud from "i'm spiraling" rains the saved thoughts back down.
                    SundayRain(count: waiting.count, color: orbPalette.colors[0])
                        .frame(height: 140)
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                Text("With fresh eyes: has it shifted?")
                    .foregroundStyle(.secondary)
            }

            if !thisWeek.isEmpty {
                Section {
                    ForEach(thisWeek) { reflection in
                        VStack(alignment: .leading, spacing: 4) {
                            if !reflection.learned.isEmpty {
                                Label(reflection.learned, systemImage: "lightbulb")
                            }
                            if !reflection.interesting.isEmpty {
                                Label(reflection.interesting, systemImage: "sparkles")
                            }
                        }
                        .font(.callout)
                    }
                } header: {
                    Text("This week you learned and enjoyed")
                } footer: {
                    Text("Weigh these alongside the doubts below.")
                }
            }

            if !lookAgain.isEmpty {
                Section {
                    ForEach(lookAgain) { reframe in
                        Button { revisiting = reframe } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                if let entry = reframe.entry, entry.kind.isText, !entry.text.isEmpty {
                                    Text("“\(entry.text)”")
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)
                                }
                                Label("how does it sit now?", systemImage: "clock.arrow.circlepath")
                                    .font(.callout)
                            }
                        }
                    }
                } header: {
                    Text("Look again")
                } footer: {
                    Text("Sometimes the heart needs a few days to catch up with the head.")
                }
            }

            if waiting.isEmpty && lookAgain.isEmpty {
                Section {
                    Text("Nothing waiting.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(waiting) { thought in
                Section {
                    ParkedReviewRow(thought: thought)
                } header: {
                    Text("Parked \(thought.createdAt.formatted(.relative(presentation: .named)))")
                }
            }

            if !reviewed.isEmpty {
                Section("Looked at") {
                    ForEach(reviewed) { thought in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thought.text)
                            LabeledRing(amount: thought.urgencyAtReview, label: "how urgent it felt later")
                            if !thought.reviewNote.isEmpty {
                                Text(thought.reviewNote)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $revisiting) { RevisitView(reframe: $0) }
        .navigationTitle("sunday look-back")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { if waiting.isEmpty { ReminderScheduler.cancelSundayReview() } }
        .themedBackground()
        .paperList()
        .keyboardDoneButton()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct ParkedReviewRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var thought: ParkedThought

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("“\(thought.text)”")
                .font(.system(.body, design: .serif))
            RatingSlider(title: "How urgent does it feel now?", value: $thought.urgencyAtReview,
                         lowLabel: "Faded", highLabel: "Still pressing")
            TextField("What have you learned or enjoyed since?", text: $thought.reviewNote, axis: .vertical)
            Button("Mark as looked at") {
                withAnimation { thought.reviewedAt = .now }
                try? context.save()
            }
            .font(.subheadline.weight(.semibold))
            // Without this, tapping anywhere in the row would trigger the button.
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
