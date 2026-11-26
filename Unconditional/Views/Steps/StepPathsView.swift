import SwiftUI
import SwiftData

/// "One step at a time": the things that feel daunting, each with a trail of footprints.
struct StepPathsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \StepPath.createdAt, order: .reverse) private var paths: [StepPath]
    @State private var adding = false
    @State private var newTitle = ""

    private var walking: [StepPath] { paths.filter { !$0.isResting } }
    private var resting: [StepPath] { paths.filter(\.isResting) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Something big or daunting gets a path. You don't plan it or measure it. You just leave a footprint each time you take a step, however small, and however it went.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                if paths.isEmpty {
                    GentleEmpty(symbol: "shoeprints.fill", title: "No paths yet",
                                message: "A job search, a hard conversation, a project you keep putting off. Name it, and start with one step.")
                        .listRowBackground(Color.clear)
                }

                if !walking.isEmpty {
                    Section("walking") {
                        ForEach(walking) { row($0) }
                    }
                }
                if !resting.isEmpty {
                    Section {
                        ForEach(resting) { row($0) }
                    } header: {
                        Text("resting")
                    } footer: {
                        Text("Set aside for now. Your footprints are still here whenever you come back.")
                    }
                }
            }
            .themedBackground()
            .paperList()
            .navigationTitle("one step at a time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Something daunting", systemImage: "plus") { adding = true }
                }
            }
            .alert("What feels daunting?", isPresented: $adding) {
                TextField("For example: finding a job", text: $newTitle)
                Button("Cancel", role: .cancel) { newTitle = "" }
                Button("Start a path") { addPath() }
            } message: {
                Text("A few words is enough.")
            }
        }
    }

    private func row(_ path: StepPath) -> some View {
        NavigationLink {
            PathView(path: path)
        } label: {
            HStack(spacing: 14) {
                Footprint(isLeft: true)
                    .frame(width: 14, height: 30)
                    .foregroundStyle(Sand.print)
                    .rotationEffect(.degrees(-8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(path.title)
                        .font(.system(.body, design: .serif))
                    Text(path.steps.isEmpty ? "No steps yet" : "\(path.steps.count) step\(path.steps.count == 1 ? "" : "s") taken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button(path.isResting ? "Keep walking" : "Rest it for now",
                   systemImage: path.isResting ? "figure.walk" : "moon") {
                withAnimation(.calm) { path.isResting.toggle() }
            }
            Button("Remove", systemImage: "trash") {
                withAnimation(.calm) { context.delete(path) }
            }
        }
    }

    private func addPath() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTitle = ""
        guard !title.isEmpty else { return }
        withAnimation(.calm) { context.insert(StepPath(title: title)) }
    }
}

// MARK: - The path itself

/// One path as footprints in the sand, walking up the screen from the first step.
/// The newest print sits at the top, closest to the horizon.
struct PathView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let path: StepPath
    @State private var takingStep = false
    @State private var stepText = ""
    /// The print you just made, so it can press into the sand.
    @State private var freshID: PersistentIdentifier?
    @State private var pressCount = 0

    /// Vertical room for each print.
    private let rowHeight: CGFloat = 86

    var body: some View {
        let steps = path.walked
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    horizon
                        .id("top")
                    // Newest first, so the trail runs from the bottom of the screen upward.
                    ForEach(Array(steps.enumerated().reversed()), id: \.element.persistentModelID) { index, step in
                        printRow(step, index: index)
                    }
                    if steps.isEmpty {
                        Text("Your first footprint will appear here.")
                            .font(.callout)
                            .foregroundStyle(Sand.ink.opacity(0.7))
                            .padding(.top, 40)
                    }
                    Text("started \(path.createdAt.formatted(.dateTime.month(.wide).day()))")
                        .font(.caption)
                        .foregroundStyle(Sand.ink.opacity(0.6))
                        .padding(.vertical, 28)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 120)
            }
            .defaultScrollAnchor(.bottom)
            .background { SandBackground(reduceMotion: reduceMotion).ignoresSafeArea() }
            .safeAreaInset(edge: .bottom) {
                Button("Take a step") { takingStep = true }
                    .buttonStyle(.paper)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .navigationTitle(path.title.lowercased())
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: pressCount)
            .sheet(isPresented: $takingStep) {
                stepSheet(onSave: {
                    withAnimation(.calm) { reader.scrollTo("top", anchor: .top) }
                })
                .presentationDetents([.medium])
            }
        }
    }

    /// The thing you're walking toward, faint, like a shape on the horizon.
    /// No distance, no percentage: just the direction.
    private var horizon: some View {
        VStack(spacing: 6) {
            Text("toward")
                .font(.caption)
                .foregroundStyle(Sand.ink.opacity(0.6))
            Text(path.title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Sand.ink.opacity(0.8))
                .multilineTextAlignment(.center)
            Text("Every print counts the same, however it went.")
                .font(.footnote)
                .foregroundStyle(Sand.ink.opacity(0.65))
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    /// One footprint, swaying left and right along a gently winding path,
    /// with what you did written beside it.
    private func printRow(_ step: Footstep, index: Int) -> some View {
        let isLeft = index.isMultiple(of: 2)
        // The trail winds slowly; left and right feet sit either side of it.
        let sway = CGFloat(sin(Double(index) * 0.7)) * 46 + (isLeft ? -16 : 16)
        let tilt = cos(Double(index) * 0.7) * 14
        let age = Date.now.timeIntervalSince(step.createdAt) / 86_400
        let fresh = freshID == step.persistentModelID
        return ZStack {
            Footprint(isLeft: isLeft)
                .frame(width: 26, height: 56)
                .foregroundStyle(Sand.print)
                .overlay {
                    // A lighter rim, like the sand pushed up around the print.
                    Footprint(isLeft: isLeft)
                        .stroke(Sand.rim, lineWidth: 1.2)
                        .offset(x: -0.8, y: -1)
                }
                .rotationEffect(.degrees(tilt))
                .opacity(Footstep.softness(age: age))
                .background {
                    if fresh && !reduceMotion { SandPuff(trigger: pressCount) }
                }
                .offset(x: sway)

            // What you did, on the side with more room.
            Text(step.text)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(Sand.ink)
                .lineLimit(3)
                .frame(width: 130, alignment: sway < 0 ? .leading : .trailing)
                .multilineTextAlignment(sway < 0 ? .leading : .trailing)
                .offset(x: sway < 0 ? sway + 100 : sway - 100)
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
        // A new print presses in: a touch bigger at first, then settling into the sand.
        .transition(.scale(scale: 1.3).combined(with: .opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step: \(step.text), \(step.createdAt.formatted(date: .abbreviated, time: .omitted))")
        .contextMenu {
            Button("Remove this step", systemImage: "trash") {
                withAnimation(.calm) { context.delete(step) }
            }
        }
    }

    private func stepSheet(onSave: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("What did you do?")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                Text("Small counts. Opening the document counts. Sending one email counts. How it went doesn't change the print.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("One step I took", text: $stepText, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                Button("Leave a footprint") {
                    leavePrint()
                    onSave()
                }
                .buttonStyle(.paper)
                .disabled(stepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { takingStep = false }
                }
            }
        }
    }

    private func leavePrint() {
        let text = stepText.trimmingCharacters(in: .whitespacesAndNewlines)
        stepText = ""
        takingStep = false
        guard !text.isEmpty else { return }
        // Let the sheet slide away first, then press the print into the sand.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.6, bounce: 0.45)) {
                let step = Footstep(text: text)
                context.insert(step)
                step.path = path
                if path.isResting { path.isResting = false }
                freshID = step.persistentModelID
            }
            pressCount += 1
        }
    }
}

// MARK: - Sand

enum Sand {
    static let light = Color(light: 0xF4EBDD, dark: 0x2A251E)
    static let deep = Color(light: 0xEADBC4, dark: 0x221E18)
    /// A pressed print: a little darker than the sand around it.
    static let print = Color(light: 0xD7C3A4, dark: 0x3A3228)
    static let rim = Color(light: 0xFBF5EC, dark: 0x4A4136)
    static let ink = Color(light: 0x5B4A36, dark: 0xE4D6C2)
}

/// Warm sand, with a soft wash of water easing in and out along the bottom.
struct SandBackground: View {
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Sand.light, Sand.deep]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                // The wash: a slow, wavy edge of water that comes up a little and goes back.
                let reach = size.height * (0.05 + 0.025 * (reduceMotion ? 0 : sin(t * 0.35)))
                var water = Path()
                water.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0, through: size.width, by: 6) {
                    let y = size.height - reach + 5 * sin(x / 38 + t * 0.6)
                    water.addLine(to: CGPoint(x: x, y: y))
                }
                water.addLine(to: CGPoint(x: size.width, y: size.height))
                water.closeSubpath()
                ctx.fill(water, with: .color(Color(light: 0xCFE3E8, dark: 0x1F2C30).opacity(0.55)))
                ctx.stroke(water, with: .color(.white.opacity(0.5)), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A few grains of sand kicked up when a print presses in.
private struct SandPuff: View {
    let trigger: Int
    @State private var spread = false

    var body: some View {
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                let angle = Double(i) / 9 * 2 * .pi
                Circle()
                    .fill(Sand.print)
                    .frame(width: 3, height: 3)
                    .offset(x: spread ? cos(angle) * 30 : 0, y: spread ? sin(angle) * 34 : 0)
                    .opacity(spread ? 0 : 0.9)
            }
        }
        .onChange(of: trigger, initial: true) { _, _ in
            spread = false
            withAnimation(.easeOut(duration: 0.7)) { spread = true }
        }
    }
}

// MARK: - A footprint

/// A bare footprint: heel, a narrower arch, the ball of the foot, and five toes.
/// Drawn as one shape so it can be filled, stroked, and mirrored for the other foot.
struct Footprint: Shape {
    var isLeft: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        // Sole: heel at the bottom, ball near the top, a slightly narrower arch between.
        // Joined with `union`, so it's one outline (overlapping pieces don't cut holes).
        var sole = Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.66, width: w * 0.62, height: h * 0.32))   // heel
            .union(Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.24, width: w * 0.84, height: h * 0.40)))   // ball
            .union(Path(roundedRect: CGRect(x: w * 0.24, y: h * 0.46, width: w * 0.48, height: h * 0.32),
                        cornerRadius: w * 0.2))                                                          // arch
        // Toes, biggest on the inside of the foot (drawn here as a right foot).
        let toes: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (0.22, 0.12, 0.17), (0.45, 0.07, 0.12), (0.62, 0.08, 0.105), (0.77, 0.12, 0.09), (0.89, 0.19, 0.075),
        ]
        for toe in toes {
            let r = toe.r * w
            sole = sole.union(Path(ellipseIn: CGRect(x: toe.x * w - r, y: toe.y * h - r * 0.9, width: r * 2, height: r * 1.8)))
        }
        var path = sole.offsetBy(dx: rect.minX, dy: rect.minY)
        // Mirror for the left foot.
        if isLeft {
            path = path.applying(CGAffineTransform(translationX: rect.midX, y: 0).scaledBy(x: -1, y: 1).translatedBy(x: -rect.midX, y: 0))
        }
        return path
    }
}
