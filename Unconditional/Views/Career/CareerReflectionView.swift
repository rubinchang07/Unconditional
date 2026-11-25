import SwiftUI
import SwiftData

/// After studying or job searching: what did you learn, what was interesting,
/// and if you feel like quitting, is it the work or the discouragement?
struct CareerReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var moment: CareerMoment = .study
    @State private var topic = ""
    @State private var learned = ""
    @State private var interesting = ""
    @State private var enjoyment = 5.0
    @State private var discouragement = 5.0
    @State private var urgeToQuit = 0.0
    @State private var quitSource = 0.5
    @State private var parkIt = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Group {
                if saved {
                    savedView
                } else {
                    form
                }
            }
            .navigationTitle("career check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !saved {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("What was it?", selection: $moment) {
                    ForEach(CareerMoment.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                TextField(moment.topicPrompt, text: $topic, axis: .vertical)
            }

            Section {
                TextField("Even something small counts", text: $learned, axis: .vertical)
            } header: {
                Text("What did you learn?")
            }

            Section {
                TextField("A moment that clicked, a problem you liked, a person you met", text: $interesting, axis: .vertical)
            } header: {
                Text("What was interesting or felt good?")
            }

            Section {
                RatingSlider(title: "Enjoyed the work itself", value: $enjoyment,
                             lowLabel: "Not at all", highLabel: "A lot")
                RatingSlider(title: "Feeling discouraged", value: $discouragement,
                             lowLabel: "Not at all", highLabel: "Very")
                RatingSlider(title: "Urge to quit", value: $urgeToQuit,
                             lowLabel: "None", highLabel: "Strong")
            } header: {
                Text("How it felt")
            } footer: {
                Text("You can enjoy something and feel discouraged by it at the same time. Both can be true.")
            }

            if urgeToQuit >= 3 {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Where is the urge to quit coming from?")
                        Slider(value: $quitSource, in: 0...1)
                            .accessibilityLabel("Source of the urge to quit")
                        HStack(alignment: .top) {
                            Text("I don't like\nthe work itself")
                            Spacer()
                            Text("I feel discouraged\nor not good enough")
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Toggle("Park this for my weekly review", isOn: $parkIt)
                } footer: {
                    Text("This isn't about talking you out of a change. It's about making big decisions from a calm place, not in a hard moment.")
                }
            }
        }
        .themedBackground()
        .paperList()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .animation(.easeInOut, value: urgeToQuit >= 3)
    }

    private var savedView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "leaf")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Saved.")
                .font(.system(.title, design: .serif).weight(.semibold))
            Text(closingMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.paper)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeBackground())
    }

    /// A gentle, descriptive note. It reflects back, it doesn't judge.
    private var closingMessage: String {
        if urgeToQuit >= 3 && quitSource > 0.6 {
            return "It sounds like the urge to quit is coming more from discouragement than from the work itself. That's worth knowing. Discouragement tends to change faster than interest does."
        }
        if urgeToQuit >= 3 && quitSource < 0.4 {
            return "It sounds like the work itself might not be a fit right now. That's real information, and it deserves a calm look in your weekly review."
        }
        if !learned.trimmingCharacters(in: .whitespaces).isEmpty {
            return "You learned something today. That stays with you, whatever the outcome."
        }
        return "Showing up for this counts, whatever the outcome."
    }

    private func save() {
        let reflection = CareerReflection(moment: moment, topic: topic.trimmingCharacters(in: .whitespacesAndNewlines))
        reflection.learned = learned.trimmingCharacters(in: .whitespacesAndNewlines)
        reflection.interesting = interesting.trimmingCharacters(in: .whitespacesAndNewlines)
        reflection.enjoyment = enjoyment
        reflection.discouragement = discouragement
        reflection.urgeToQuit = urgeToQuit
        reflection.quitSource = quitSource
        context.insert(reflection)

        if parkIt && urgeToQuit >= 3 {
            let what = reflection.topic.isEmpty ? moment.label.lowercased() : reflection.topic
            context.insert(ParkedThought(text: "Urge to quit after \(what)"))
        }
        try? context.save()
        withAnimation { saved = true }
    }
}

/// All career reflections, newest first, plus a plain-language summary.
struct CareerHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CareerReflection.createdAt, order: .reverse) private var reflections: [CareerReflection]
    @State private var showNew = false
    @State private var showReview = false

    var body: some View {
        List {
            if !reflections.isEmpty {
                Section {
                    CareerSummary(reflections: reflections)
                } header: {
                    Text("Across \(reflections.count) reflection\(reflections.count == 1 ? "" : "s")")
                } footer: {
                    Text("A description, not a verdict. Patterns can change.")
                }
            }

            Section {
                Button("New check-in", systemImage: "plus") { showNew = true }
                Button("Weekly review", systemImage: "tray") { showReview = true }
            }

            ForEach(reflections) { reflection in
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(reflection.topic.isEmpty ? reflection.moment.label : reflection.topic,
                              systemImage: reflection.moment.symbol)
                            .font(.system(.headline, design: .serif))
                        if !reflection.learned.isEmpty {
                            Text("Learned: \(reflection.learned)").font(.callout)
                        }
                        if !reflection.interesting.isEmpty {
                            Text("Interesting: \(reflection.interesting)").font(.callout)
                        }
                        // Rings rather than numbers, so looking back doesn't feel like a report card.
                        HStack(spacing: 16) {
                            LabeledRing(amount: reflection.enjoyment, label: "enjoyed")
                            LabeledRing(amount: reflection.discouragement, label: "discouraged")
                            LabeledRing(amount: reflection.urgeToQuit, label: "urge to quit")
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 2)
                    .gentleRemove { context.delete(reflection) }
                } header: {
                    Text(reflection.createdAt, format: .dateTime.weekday().month().day())
                }
            }
            if reflections.isEmpty {
                GentleEmpty(symbol: "briefcase", title: "No check-ins yet",
                            message: "After studying or applying, a minute here can help you see what you're learning, not just what's hard.")
            }
        }
        .navigationTitle("career")
        .themedBackground()
        .paperList()
        .sheet(isPresented: $showNew) { CareerReflectionView() }
        .sheet(isPresented: $showReview) {
            NavigationStack { ParkedReviewView() }
        }
    }
}

/// Plain-language averages: enjoyment vs discouragement, and where quit urges come from.
struct CareerSummary: View {
    let reflections: [CareerReflection]

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        let enjoyment = average(reflections.map(\.enjoyment))
        let discouragement = average(reflections.map(\.discouragement))
        let urges = reflections.filter(\.hasUrgeToQuit)
        let fromDiscouragement = urges.filter { $0.quitSource > 0.6 }.count
        let fromWork = urges.filter { $0.quitSource < 0.4 }.count

        VStack(alignment: .leading, spacing: 12) {
            meter("Enjoyed the work", value: enjoyment)
            meter("Felt discouraged", value: discouragement)
            if !urges.isEmpty {
                Text("When you felt like quitting (\(urges.count) time\(urges.count == 1 ? "" : "s")), it came mostly from discouragement \(fromDiscouragement) time\(fromDiscouragement == 1 ? "" : "s"), and mostly from not liking the work \(fromWork) time\(fromWork == 1 ? "" : "s").")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func meter(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.tint.opacity(0.15))
                    Capsule().fill(.tint).frame(width: proxy.size.width * value / 10)
                }
            }
            .frame(height: 6)
        }
    }
}
