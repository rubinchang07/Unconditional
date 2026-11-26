import SwiftUI
import SwiftData

/// Past entries as a calendar of dots and a list, with Insights one tap away.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                            .padding(.vertical, 6)
                    }
                } footer: {
                    Text("Patterns over time, your map, and your weekly review.")
                }

                Section {
                    CalendarDots(days: dayColors)
                        .padding(.vertical, 6)
                } footer: {
                    Text("One dot for each day you checked in, colored by loop. Good moments glow warm gold.")
                }

                Section("Entries") {
                    ForEach(entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .gentleRemove { context.delete(entry) }
                    }
                    if entries.isEmpty {
                        GentleEmpty(symbol: "leaf", title: "Nothing here yet",
                                    message: "Whenever you check in, it'll be kept here. There's no schedule to keep up with.")
                    }
                }
            }
            .navigationTitle("reflect")
            .themedBackground()
            .paperList()
        }
    }

    /// The colors of the loops you wrote about each day. Unnamed entries are grey.
    private var dayColors: [Date: [Color]] {
        var result: [Date: [Color]] = [:]
        for entry in entries {
            let day = Calendar.current.startOfDay(for: entry.createdAt)
            let color: Color
            if entry.isGood {
                // Good moments glow warm, like sunlight.
                color = Color(hex: 0xF6C38B)
            } else if let loop = entry.loop, let index = loops.firstIndex(of: loop) {
                color = Color(hex: Loop.palette[index % Loop.palette.count])
            } else {
                color = Color.secondary.opacity(0.5)
            }
            if !(result[day]?.contains(color) ?? false) { result[day, default: []].append(color) }
        }
        return result
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            if entry.kind == .draw {
                DrawingThumbnail(data: entry.drawingData,
                                 background: CanvasBackground(rawValue: entry.drawingBackground) ?? .paper)
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
                    if entry.isGood { Label("Something good", systemImage: "sun.max") }
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
            Section {
                TextField("The belief that keeps it going", text: $loop.coreBelief, axis: .vertical)
            } header: {
                Text("Core belief")
            } footer: {
                Text("For example: \"If I struggle, it means I'm not good enough.\" Optional, and you can change it as you understand it better.")
            }
            Section {
                TextField("Optional", text: $loop.pattern, axis: .vertical)
            } header: {
                Text("How it tends to go")
            } footer: {
                Text("The steps it usually follows, like \"comparison, then urgency, then freezing up\".")
            }
        }
        .navigationTitle(loop.name)
        .themedBackground()
        .keyboardDoneButton()
        .navigationBarTitleDisplayMode(.inline)
    }
}
