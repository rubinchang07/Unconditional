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
                    LabeledText(title: "Distress", value: "\(Int(reframe.distressBefore)) → \(Int(reframe.distressAfter)) out of 10")
                    LabeledText(title: "Believed the thought", value: "\(Int(reframe.beliefBefore))% → \(Int(reframe.beliefAfter))%")
                    LabeledText(title: "What happened", value: reframe.trigger)
                    LabeledText(title: "The belief underneath", value: reframe.coreBelief)
                    LabeledText(title: "Evidence for", value: reframe.evidenceFor)
                    LabeledText(title: "Evidence against", value: reframe.evidenceAgainst)
                    LabeledText(title: "A kinder read", value: reframe.kinderRead)
                    LabeledText(title: "One small step", value: reframe.smallStep)
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
