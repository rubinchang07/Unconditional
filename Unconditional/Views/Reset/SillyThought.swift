import SwiftUI
import AVFoundation

/// "Make it silly": the thought, said by a cartoon version of the orb in a speech
/// bubble, and read aloud in a squeaky or sleepy voice if you like.
///
/// This is a defusion skill from ACT: a thought heard in a silly voice is still
/// the same words, but it's easier to notice that it's a thought, not a fact.
/// It isn't laughing at you or at how hard it feels. It just loosens the grip.
struct SillyThoughtView: View {
    let thought: String
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage
    @State private var voice = SillyVoice()
    @State private var havingThought = true

    private var spoken: String {
        havingThought ? "I'm having the thought that \(Self.lowercasedFirst(thought))" : thought
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    SpeechBubble(text: spoken)
                        .padding(.top, 12)
                        .animation(.calm, value: havingThought)

                    CartoonOrb(palette: palette, talking: voice.isSpeaking)
                        .frame(width: 150, height: 150)
                        .padding(.vertical, 6)

                    Toggle("Start with “I'm having the thought that…”", isOn: $havingThought)
                        .font(.subheadline)
                        .paperCard(padding: 14)

                    VStack(spacing: 10) {
                        Text("Hear it in a silly voice")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            voiceButton("squeaky", symbol: "bird", style: .squeaky)
                            voiceButton("slow and sleepy", symbol: "tortoise", style: .sleepy)
                        }
                    }

                    Text("Same words, different voice. It's still a thought, not a fact.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(ThemeBackground())
            .navigationTitle("make it silly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        voice.stop()
                        onDone()
                    }
                }
            }
            .onDisappear { voice.stop() }
        }
    }

    private func voiceButton(_ title: String, symbol: String, style: SillyVoice.Style) -> some View {
        Button {
            voice.say(spoken, style: style)
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.tint.opacity(0.13), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    /// "I'm having the thought that I always mess things up", not "...that I Always...".
    /// Leaves "I" and words like "NASA" alone.
    static func lowercasedFirst(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(separator: " ").first else { return trimmed }
        let word = String(first)
        if word == "I" || word.hasPrefix("I'") || word.hasPrefix("I’") || word == word.uppercased() { return trimmed }
        return word.prefix(1).lowercased() + trimmed.dropFirst()
    }
}

/// Reads text aloud in a silly voice, on the phone.
@Observable
final class SillyVoice: NSObject, AVSpeechSynthesizerDelegate {
    enum Style {
        case squeaky, sleepy

        var pitch: Float { self == .squeaky ? 2.0 : 0.55 }
        var rate: Float {
            self == .squeaky ? AVSpeechUtteranceDefaultSpeechRate * 1.05 : AVSpeechUtteranceMinimumSpeechRate + 0.12
        }
    }

    private(set) var isSpeaking = false
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String, style: Style) {
        stop()
        // Plays even with the ring switch on silent, and only lowers other audio.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        let utterance = AVSpeechUtterance(string: text)
        utterance.pitchMultiplier = style.pitch
        utterance.rate = style.rate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

/// The orb, with a cartoon face: two eyes that blink now and then and a mouth
/// that smiles, or chatters while it talks.
struct CartoonOrb: View {
    let palette: OrbPalette
    var talking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let bob = talking && !reduceMotion ? sin(t * 9) * 3 : 0
            ZStack {
                OrbView(palette: palette, state: talking ? .listening : .resting, level: talking ? 0.5 : 0, exercise: true)
                Canvas { ctx, size in
                    let w = size.width, h = size.height
                    // A blink lasts a moment, about every three and a half seconds.
                    let blinking = !reduceMotion && t.truncatingRemainder(dividingBy: 3.6) < 0.14
                    let eyeH = blinking ? h * 0.02 : h * 0.13
                    for side: CGFloat in [-1, 1] {
                        let cx = w / 2 + side * w * 0.14
                        let eye = CGRect(x: cx - w * 0.055, y: h * 0.38 - eyeH / 2, width: w * 0.11, height: eyeH)
                        ctx.fill(Path(ellipseIn: eye), with: .color(.white))
                        if !blinking {
                            let pupil = CGRect(x: cx - w * 0.028 + side * w * 0.008, y: h * 0.39 - w * 0.028,
                                               width: w * 0.056, height: w * 0.056)
                            ctx.fill(Path(ellipseIn: pupil), with: .color(Color(hex: 0x2B2B33)))
                        }
                    }
                    if talking {
                        let open = reduceMotion ? 0.5 : 0.25 + 0.75 * abs(sin(t * 11))
                        let mouth = CGRect(x: w / 2 - w * 0.08, y: h * 0.58, width: w * 0.16, height: h * 0.04 + h * 0.1 * open)
                        ctx.fill(Path(ellipseIn: mouth), with: .color(Color(hex: 0x2B2B33).opacity(0.85)))
                    } else {
                        var smile = Path()
                        smile.move(to: CGPoint(x: w * 0.4, y: h * 0.6))
                        smile.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.6), control: CGPoint(x: w / 2, y: h * 0.69))
                        ctx.stroke(smile, with: .color(Color(hex: 0x2B2B33).opacity(0.85)),
                                   style: StrokeStyle(lineWidth: w * 0.025, lineCap: .round))
                    }
                }
            }
            .offset(y: bob)
        }
        .accessibilityHidden(true)
    }
}

/// A comic speech bubble with a little tail pointing down at the orb.
private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text("“\(text)”")
            .font(.system(.title3).weight(.bold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            // Room underneath for the tail.
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity)
            .background {
                BubbleShape()
                    .fill(Paper.card)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                BubbleShape()
                    .stroke(.primary.opacity(0.75), lineWidth: 2.5)
            }
            .accessibilityLabel(text)
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 18)
        var path = Path(roundedRect: body, cornerRadius: 26, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.midX - 14, y: body.maxY - 2))
        tail.addLine(to: CGPoint(x: rect.midX + 2, y: rect.maxY))
        tail.addLine(to: CGPoint(x: rect.midX + 12, y: body.maxY - 2))
        tail.closeSubpath()
        path = path.union(tail)
        return path
    }
}
