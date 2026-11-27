import SwiftUI
import SwiftData

/// Reflect: your entries as a branch with leaves, and Insights one quiet tap away.
struct HistoryView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .midnight
    @State private var released = false
    @State private var settled = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("insights", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)

                    if entries.isEmpty {
                        GentleEmpty(symbol: "leaf", title: "Nothing here yet",
                                    message: "Every check-in becomes a leaf here. There's no schedule to keep up with.")
                            .padding(.top, 40)
                    } else {
                        // The orb's light breaks apart in its own small space, which then
                        // closes up, and the leaves grow from where it was.
                        if !settled {
                            DispersingOrb(palette: orbPalette, dispersed: released)
                                .frame(width: 44, height: 44)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .task {
                                    try? await Task.sleep(for: .milliseconds(200))
                                    released = true
                                    try? await Task.sleep(for: .milliseconds(900))
                                    withAnimation(.easeInOut(duration: 0.6)) { settled = true }
                                }
                        }
                        EntryBranch(entries: entries)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)
            }
            .contentMargins(.bottom, 80, for: .scrollContent)
            .navigationTitle("reflect")
            .themedBackground()
        }
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
