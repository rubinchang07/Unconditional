import SwiftUI
import SwiftData

/// A second look at a reframe, a few days later. Sometimes the heart just needs
/// time to catch up with the head. One slider per screen, heart then head, each
/// answered fresh without seeing the old answer, and
/// then the waves from then above the waves from now. The first answers are
/// never changed: they're how you can see whether anything moved.
struct RevisitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var reframe: Reframe

    private enum Step { case heart, head, compare }
    @State private var step: Step = .heart
    /// Both start in the middle, not at last time's answers, so the new reading is
    /// your own and not anchored to the old one. The two only meet at the end.
    @State private var heart = 0.5
    @State private var head = 0.5

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .heart:
                    question("In your heart, how heavy does it feel now?", icon: "heart", value: $heart) {
                        withAnimation(.calm) { step = .head }
                    }
                case .head:
                    question("Stepped back, how heavy does it look now?", icon: "brain.head.profile", value: $head) {
                        save()
                        withAnimation(.calm) { step = .compare }
                    }
                case .compare:
                    compare
                }
            }
            .id(step)
            .transition(.calmSwap())
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThemeBackground())
            .navigationTitle("look again")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .compare {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
        }
    }

    private func question(_ title: String, icon: String, value: Binding<Double>, next: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if let entry = reframe.entry, entry.kind.isText, !entry.text.isEmpty {
                Text("“\(entry.text)”")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 16)
            }
            Label(title, systemImage: icon)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .softCase()
            VStack(spacing: 6) {
                Slider(value: value, in: 0...1)
                    .accessibilityLabel(title)
                    .accessibilityValue(value.wrappedValue < 0.5 ? "heavier" : "lighter")
                HStack {
                    Text("heavy")
                    Spacer()
                    Text("light")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Next", action: next)
                .buttonStyle(.paper)
        }
    }

    private var compare: some View {
        let thenGap = HeadAndHeart.gap(head: reframe.headValue, heart: reframe.heartValue)
        let nowGap = HeadAndHeart.gap(head: head, heart: heart)
        return VStack(spacing: 20) {
            Spacer()
            row("then, \(reframe.createdAt.formatted(.dateTime.month(.wide).day()))") {
                HeadAndHeartStill(head: reframe.headValue, heart: reframe.heartValue)
            }
            .opacity(0.6)
            row("now") {
                HeadAndHeartStill(head: head, heart: heart)
            }
            Text(Self.message(then: thenGap, now: nowGap))
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.paper)
        }
    }

    private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func save() {
        reframe.laterHeart = heart
        reframe.laterHead = head
        reframe.laterAt = .now
        try? context.save()
    }

    /// Describes what happened, never grades it. Still apart is allowed.
    static func message(then: Double, now: Double) -> String {
        let n = HeadAndHeart.noticeable
        if now < n && then >= n { return "They've come together. Sometimes it just takes time." }
        if now < n { return "Still in tune." }
        if now < then - 0.1 { return "A little closer than before. Still settling, and that's okay." }
        if now > then + 0.1 { return "Further apart than before. Feelings move both ways, and that isn't a step back." }
        return "Still settling. Some things take longer, and that's okay."
    }
}
