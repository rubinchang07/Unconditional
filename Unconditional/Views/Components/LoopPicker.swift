import SwiftUI
import SwiftData

/// "Which loop is this?" A picker over the seeded loops, with "Not sure" as an option.
struct LoopPicker: View {
    @Binding var selection: Loop?
    @Query(sort: \Loop.sortOrder) private var loops: [Loop]

    var body: some View {
        Picker("Which loop is this?", selection: $selection) {
            Text("Not sure yet").tag(Loop?.none)
            ForEach(loops) { loop in
                Text(loop.name).tag(Optional(loop))
            }
        }
        if let selection {
            Text("“\(selection.coreBelief)”")
                .font(.footnote)
                .italic()
                .foregroundStyle(.secondary)
        }
    }
}
