import SwiftUI
import SwiftData

/// Pick starter loops as chips, or write your own. Used in the welcome tour
/// and in Settings → Your loops.
struct LoopChooser: View {
    @Binding var picked: Set<LoopStarter>
    @Binding var custom: [String]
    /// Starters you already have are hidden.
    var existingNames: Set<String> = []
    @State private var draft = ""

    private var starters: [LoopStarter] {
        LoopStarter.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(starters) { starter in
                    chip(starter.name, on: picked.contains(starter)) {
                        if picked.contains(starter) { picked.remove(starter) } else { picked.insert(starter) }
                    }
                }
                ForEach(custom, id: \.self) { name in
                    chip(name, on: true) { custom.removeAll { $0 == name } }
                }
            }

            HStack {
                TextField("Or name your own", text: $draft)
                    .onSubmit(addDraft)
                Button("Add", action: addDraft)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .sensoryFeedback(.selection, trigger: picked.count + custom.count)
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(on ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(Paper.card),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func addDraft() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !custom.contains(name) else { return }
        Keyboard.hide()
        custom.append(name)
        draft = ""
    }
}

/// Settings → Your loops: reorder, rename, remove, or add more.
struct LoopsManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]
    @State private var adding = false
    /// Your own guess at what might sit underneath all the loops. Never decided by the app.
    @AppStorage("mapRoot") private var root = ""

    var body: some View {
        List {
            Section {
                ForEach(loops) { loop in
                    NavigationLink {
                        LoopEditView(loop: loop)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loop.name)
                            if !loop.coreBelief.isEmpty {
                                Text(loop.coreBelief).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .gentleRemove { context.delete(loop) }
                }
                .onMove(perform: move)
            } footer: {
                Text("Removing a loop keeps its entries. They just won't have a loop any more.")
            }

            Section {
                Button("Add loops", systemImage: "plus") { adding = true }
            }

            Section {
                TextField("For example: needing to earn being okay", text: $root, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("Underneath it all")
            } footer: {
                Text("Your own guess at what the loops might share. Optional, and only ever yours to change.")
            }
        }
        .navigationTitle("your loops")
        .themedBackground()
        .paperList()
        .toolbar { EditButton() }
        .overlay {
            if loops.isEmpty {
                GentleEmpty(symbol: "arrow.triangle.2.circlepath", title: "No loops yet",
                            message: "Loops are the thoughts you tend to get stuck on. Add a few to start noticing them.")
            }
        }
        .sheet(isPresented: $adding) { AddLoopsSheet() }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = loops
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, loop) in ordered.enumerated() { loop.sortOrder = index }
    }
}

private struct AddLoopsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var loops: [Loop]
    @State private var picked: Set<LoopStarter> = []
    @State private var custom: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LoopChooser(picked: $picked, custom: $custom,
                            existingNames: Set(loops.map { $0.name.lowercased() }))
                    .padding()
            }
            .navigationTitle("add loops")
            .navigationBarTitleDisplayMode(.inline)
            .themedBackground()
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        LoopStarter.add(starters: Array(picked), custom: custom, to: context)
                        dismiss()
                    }
                    .disabled(picked.isEmpty && custom.isEmpty)
                }
            }
        }
    }
}
