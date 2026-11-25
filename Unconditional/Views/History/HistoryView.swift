import SwiftUI
import SwiftData
import Charts

/// Past entries, plus how often each loop shows up.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]

    var body: some View {
        NavigationStack {
            List {
                Section("Loops") {
                    if entries.isEmpty {
                        Text("Your patterns will show up here as you write.")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(loops) { loop in
                            BarMark(
                                x: .value("Entries", loop.entries.count),
                                y: .value("Loop", loop.name)
                            )
                            .foregroundStyle(.tint)
                            .cornerRadius(6)
                        }
                        .frame(height: 220)
                    }
                    ForEach(loops) { loop in
                        NavigationLink {
                            LoopEditView(loop: loop)
                        } label: {
                            LabeledContent(loop.name, value: "\(loop.entries.count)")
                        }
                    }
                }

                Section("Entries") {
                    ForEach(entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { context.delete(entries[$0]) }
                    }
                }
            }
            .navigationTitle("History")
            .themedBackground()
        }
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            if entry.kind == .draw {
                DrawingThumbnail(data: entry.drawingData)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: entry.kind.symbol)
                    .frame(width: 44)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.createdAt, format: .dateTime.weekday().month().day())
                    .font(.headline)
                if entry.kind.isText {
                    Text(entry.text).lineLimit(2).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let loop = entry.loop { Text(loop.name) }
                    if entry.reframe != nil { Label("Reframed", systemImage: "arrow.triangle.2.circlepath") }
                }
                .font(.caption)
                .foregroundStyle(.tint)
            }
        }
    }
}

/// Lets you rename a loop or rewrite its core belief as your understanding changes.
struct LoopEditView: View {
    @Bindable var loop: Loop

    var body: some View {
        Form {
            Section("Name") { TextField("Name", text: $loop.name) }
            Section("Pattern") { TextField("Pattern", text: $loop.pattern, axis: .vertical) }
            Section("Core belief") { TextField("Core belief", text: $loop.coreBelief, axis: .vertical) }
        }
        .navigationTitle(loop.name)
        .themedBackground()
        .keyboardDoneButton()
        .navigationBarTitleDisplayMode(.inline)
    }
}
