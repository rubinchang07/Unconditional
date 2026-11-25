import SwiftUI
import SwiftData

/// Past entries, plus how often each loop shows up.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @Query private var reframes: [Reframe]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // One row per loop: name, count, and a soft bar showing its share.
                    // Simpler and calmer than a full chart, and the bar sits right under its label.
                    ForEach(loops) { loop in
                        NavigationLink {
                            LoopEditView(loop: loop)
                        } label: {
                            LoopRow(loop: loop, maxCount: maxLoopCount)
                        }
                    }
                } header: {
                    Text("Loops")
                } footer: {
                    if entries.isEmpty {
                        Text("Your patterns will show up here as you write.")
                    }
                }

                if !reframes.isEmpty {
                    Section {
                        ReframeShift(reframes: reframes)
                    } header: {
                        Text("When you reframe")
                    } footer: {
                        Text("Averages across \(reframes.count) reframe\(reframes.count == 1 ? "" : "s"). Small shifts add up.")
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
            .paperList()
        }
    }

    private var maxLoopCount: Int {
        loops.map(\.entries.count).max() ?? 0
    }
}

private struct LoopRow: View {
    let loop: Loop
    let maxCount: Int

    private var fraction: Double {
        maxCount == 0 ? 0 : Double(loop.entries.count) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(loop.name)
                Spacer()
                Text("\(loop.entries.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            // A track with a filled portion, like a gentle progress bar.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.tint.opacity(0.15))
                    Capsule()
                        .fill(.tint)
                        .frame(width: max(fraction == 0 ? 0 : 8, proxy.size.width * fraction))
                }
            }
            .frame(height: 6)
            .animation(.easeOut, value: fraction)
        }
        .padding(.vertical, 4)
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

/// Average distress and belief, before vs after reframing.
private struct ReframeShift: View {
    let reframes: [Reframe]

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        let distressBefore = average(reframes.map(\.distressBefore))
        let distressAfter = average(reframes.map(\.distressAfter))
        let beliefBefore = average(reframes.map(\.beliefBefore))
        let beliefAfter = average(reframes.map(\.beliefAfter))

        VStack(alignment: .leading, spacing: 12) {
            row("Distress", before: distressBefore.formatted(.number.precision(.fractionLength(1))),
                after: distressAfter.formatted(.number.precision(.fractionLength(1))))
            row("Believed the thought", before: "\(Int(beliefBefore.rounded()))%", after: "\(Int(beliefAfter.rounded()))%")
        }
        .padding(.vertical, 4)
    }

    private func row(_ title: String, before: String, after: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(before).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
            Text(after)
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(.tint)
        }
        .monospacedDigit()
    }
}
