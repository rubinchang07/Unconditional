import SwiftUI
import SwiftData

/// The weekly review for parked thoughts. The point isn't to stop big changes,
/// it's to make them from a calm place instead of a spiral.
struct ParkedReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ParkedThought> { $0.reviewedAt == nil },
           sort: \ParkedThought.createdAt) private var waiting: [ParkedThought]
    @Query(filter: #Predicate<ParkedThought> { $0.reviewedAt != nil },
           sort: \ParkedThought.createdAt, order: .reverse) private var reviewed: [ParkedThought]

    var body: some View {
        List {
            Section {
                Text("Look at each thought with fresh eyes. Has it shifted? What have you learned or enjoyed since? A thought that still feels important after a calm look deserves real attention.")
                    .foregroundStyle(.secondary)
            }

            if waiting.isEmpty {
                Section {
                    Text("Nothing waiting. When a big-decision thought shows up mid-spiral, you can park it from Thought Reset.")
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
                            Text("Urgency at review: \(Int(thought.urgencyAtReview)) of 10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        .navigationTitle("Weekly review")
        .navigationBarTitleDisplayMode(.inline)
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
