import SwiftUI

/// Paired muscle relaxation (the "P" in DBT's TIPP skills): squeeze one part
/// of your body for 5 seconds, then let it go for 10 and notice the difference.
/// The orb tightens and shakes while you squeeze, and goes soft when you let go.
struct TensionReleaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .midnight

    private struct Area {
        let name: String
        let squeeze: String
        /// What to notice as it lets go. Different for each part, so it never feels like a loop.
        let release: String
    }

    private let areas = [
        Area(name: "hands", squeeze: "Make tight fists.",
             release: "Open your hands. Feel the warmth coming back into your fingers."),
        Area(name: "arms", squeeze: "Bend your elbows and tighten your arms.",
             release: "Let your arms get heavy. They don't have to hold anything right now."),
        Area(name: "shoulders", squeeze: "Lift your shoulders up toward your ears.",
             release: "Let them drop, a little lower than feels normal."),
        Area(name: "face", squeeze: "Scrunch your eyes, nose, and mouth together.",
             release: "Unclench your jaw. Let your forehead go smooth."),
        Area(name: "stomach", squeeze: "Pull your stomach in tight.",
             release: "Let your belly be soft, and breathe all the way down."),
        Area(name: "legs and feet", squeeze: "Press your feet down and curl your toes.",
             release: "Feel the floor holding you up. You can rest your weight on it."),
    ]

    private let squeezeSeconds = 5.0
    private let releaseSeconds = 10.0

    @State private var index = 0
    @State private var tensing = true
    @State private var phaseStart = Date.now
    @State private var started = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Text(title)
                .font(.system(.title, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            TimelineView(.animation(paused: reduceMotion || !tensing || !started)) { timeline in
                // The shake builds as you squeeze harder, then stops when you let go.
                let held = timeline.date.timeIntervalSince(phaseStart)
                let strength = (tensing && started && !finished && !reduceMotion) ? min(held / 1.5, 1) : 0
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                let dx: Double = (sin(t * 83) + 0.6 * sin(t * 131 + 1)) * 2.4 * strength
                let dy: Double = (sin(t * 71 + 2) + 0.6 * sin(t * 113)) * 2.4 * strength
                DispersingOrb(palette: palette, state: orbState, dispersed: finished)
                    .frame(width: 260, height: 260)
                    .offset(x: dx, y: dy)
            }
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: tensing)

            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(minHeight: 50, alignment: .top)

            Spacer()
            Button(finished ? "done" : (started ? "stop" : "start")) {
                if started { dismiss() } else { Task { await run() } }
            }
            .buttonStyle(.paper)
        }
        .padding(28)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .animation(.calm, value: index)
        .animation(.calm, value: tensing)
    }

    private var orbState: OrbState {
        if finished || !started { return finished ? .settling : .resting }
        return tensing ? .tense : .settling
    }

    private var title: String {
        if finished { return "let it all stay soft." }
        if !started { return "release tension" }
        return tensing ? "squeeze your \(areas[index].name)…" : "and let go."
    }

    private var detail: String {
        if finished { return "Notice how your body feels now. Some of that tightness was holding on for you." }
        if !started { return "Six parts of your body, about two minutes. Squeeze for 5 seconds, then let go for 10. Gentle is enough, nothing should hurt." }
        return tensing ? areas[index].squeeze : areas[index].release
    }

    private func run() async {
        started = true
        for current in areas.indices {
            index = current
            tensing = true
            phaseStart = .now
            try? await Task.sleep(for: .seconds(squeezeSeconds))
            if Task.isCancelled { return }
            tensing = false
            phaseStart = .now
            try? await Task.sleep(for: .seconds(releaseSeconds))
            if Task.isCancelled { return }
        }
        withAnimation(.calm) { finished = true }
    }
}
