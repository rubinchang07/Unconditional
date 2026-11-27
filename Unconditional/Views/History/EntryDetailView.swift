import SwiftUI
import SwiftData

/// One past entry, with its reframe (or a button to add one).
struct EntryDetailView: View {
    @Bindable var entry: Entry
    @State private var editingReframe = false
    @State private var editingCompassion = false

    var body: some View {
        List {
            Section {
                if entry.kind.isText {
                    Text(entry.text)
                } else {
                    DrawingThumbnail(data: entry.drawingData,
                                 background: CanvasBackground(rawValue: entry.drawingBackground) ?? .paper)
                        .frame(maxHeight: 320)
                }
            } header: {
                Text(entry.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
            }

            Section {
                LoopPicker(selection: $entry.loop)
            }

            if entry.hasCompassion {
                Section("Self-compassion") {
                    LabeledText(title: "This is hard", value: entry.compassionHard)
                    LabeledText(title: "Others feel this too", value: entry.compassionShared)
                    LabeledText(title: "What I need", value: entry.compassionNeed)
                }
            }

            Section("Reframe") {
                if let reframe = entry.reframe {
                    if reframe.hasHeadAndHeart {
                        // Head and heart reframes: the same two waves you saw, held still.
                        HeadAndHeartStill(head: reframe.headLight >= 0 ? reframe.headLight : reframe.headTrue,
                                          heart: 1 - reframe.distressBefore / 10)
                        LabeledText(title: "In your heart", value: reframe.coreBelief)
                        LabeledText(title: "Stepped back", value: reframe.kinderRead)
                    } else {
                        DistressOrbs(before: reframe.distressBefore, after: reframe.distressAfter, maxSize: 90)
                        // Older reframes asked how much you believed the thought; newer ones don't.
                        if reframe.beliefBefore != reframe.beliefAfter {
                            BeliefBars(before: reframe.beliefBefore, after: reframe.beliefAfter)
                                .padding(.vertical, 4)
                        }
                        LabeledText(title: "The thought", value: reframe.coreBelief)
                        LabeledText(title: "Another way to see it", value: reframe.kinderRead)
                    }
                    // The deeper fields only show when you filled them in.
                    ForEach([("What happened", reframe.trigger), ("Evidence for", reframe.evidenceFor),
                             ("Evidence against", reframe.evidenceAgainst), ("One small step", reframe.smallStep)]
                        .filter { !$0.1.isEmpty }, id: \.0) { item in
                        LabeledText(title: item.0, value: item.1)
                    }
                    Button("Edit reframe") { editingReframe = true }
                } else {
                    Button("Reframe this thought") { editingReframe = true }
                }
            }
        }
        .navigationTitle("entry")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Self-compassion", systemImage: "heart") { editingCompassion = true }
            }
        }
        .sheet(isPresented: $editingCompassion) {
            NavigationStack {
                SelfCompassionView(entry: entry, onDone: { editingCompassion = false })
            }
        }
        .themedBackground()
        .paperList()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingReframe) {
            NavigationStack {
                ReframeView(entry: entry, onDone: { editingReframe = false })
            }
        }
    }
}

private struct LabeledText: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
        }
    }
}
