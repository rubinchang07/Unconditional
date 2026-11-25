import SwiftUI
import SwiftData

/// One past entry, with its reframe (or a button to add one).
struct EntryDetailView: View {
    @Bindable var entry: Entry
    @State private var editingReframe = false

    var body: some View {
        List {
            Section {
                if entry.kind == .write {
                    Text(entry.text)
                } else {
                    DrawingThumbnail(data: entry.drawingData)
                        .frame(maxHeight: 320)
                }
            } header: {
                Text(entry.createdAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
            }

            Section {
                LoopPicker(selection: $entry.loop)
            }

            Section("Reframe") {
                if let reframe = entry.reframe {
                    LabeledText(title: "What happened", value: reframe.trigger)
                    LabeledText(title: "The belief underneath", value: reframe.coreBelief)
                    LabeledText(title: "A kinder read", value: reframe.kinderRead)
                    LabeledText(title: "One small step", value: reframe.smallStep)
                    Button("Edit reframe") { editingReframe = true }
                } else {
                    Button("Reframe this thought") { editingReframe = true }
                }
            }
        }
        .navigationTitle("Entry")
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
