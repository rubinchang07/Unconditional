import SwiftUI

/// One minute of slow breathing: in for 4 seconds, out for 6.
/// A longer out-breath helps the body settle, so the mind has room to think.
struct BreathingView: View {
    @Environment(\.dismiss) private var dismiss

    private let inhale = 4.0
    private let exhale = 6.0
    private let rounds = 6 // 6 × 10 seconds = 1 minute

    @State private var round = 0
    @State private var isInhaling = true
    @State private var expanded = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(finished ? "That's a minute." : (isInhaling ? "Breathe in…" : "Breathe out…"))
                .font(.system(.title, design: .serif).weight(.semibold))
                .contentTransition(.opacity)

            ZStack {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 260, height: 260)
                Circle()
                    .fill(.tint.opacity(0.45))
                    .frame(width: 260, height: 260)
                    .scaleEffect(expanded ? 1 : 0.4)
            }
            .accessibilityHidden(true)

            Text(finished
                 ? "Whatever you're feeling is allowed to be here. You can take the next step when you're ready."
                 : "Round \(min(round + 1, rounds)) of \(rounds)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()
            Button(finished ? "Done" : "Stop early") { dismiss() }
                .buttonStyle(.paper)
        }
        .padding(28)
        .background(ThemeBackground())
        .task { await breathe() }
    }

    private func breathe() async {
        for current in 0..<rounds {
            round = current
            isInhaling = true
            withAnimation(.easeInOut(duration: inhale)) { expanded = true }
            try? await Task.sleep(for: .seconds(inhale))
            isInhaling = false
            withAnimation(.easeInOut(duration: exhale)) { expanded = false }
            try? await Task.sleep(for: .seconds(exhale))
            if Task.isCancelled { return }
        }
        withAnimation { finished = true }
    }
}
