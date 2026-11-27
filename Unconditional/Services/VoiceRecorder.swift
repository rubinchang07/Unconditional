import Foundation
import AVFoundation
import Speech
import Observation

/// Records from the microphone and turns speech into text, live.
///
/// Uses Apple's Speech framework. When the phone supports it, recognition runs
/// fully on-device, so your words never leave the phone.
///
/// `@Observable` makes SwiftUI re-draw any view that reads `transcript`
/// or `isRecording` whenever they change.
@Observable
final class VoiceRecorder {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?
    /// How loud your voice is right now, 0 to 1. The orb grows gently with it.
    var level: Double = 0

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    /// Words already settled. After a pause the recognizer can start a fresh
    /// transcription, or finish its task entirely; what came before is kept here
    /// so nothing you said disappears.
    private var committed = ""
    /// What the recognizer is working on right now.
    private var current = ""
    /// Fresh tasks started in a row with no words in between, so silence can't loop forever.
    private var emptyRestarts = 0

    func start() async {
        errorMessage = nil
        guard await Self.requestPermissions() else {
            errorMessage = "Unconditional needs microphone and speech recognition access. You can turn them on in the Settings app under Unconditional."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            transcript = ""
            committed = ""
            current = ""
            emptyRestarts = 0
            listen(with: recognizer)
            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            errorMessage = "Couldn't start recording: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        isRecording = false
        request?.endAudio() // lets the recognizer finish the last words
        request = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// A new request and recognition task, fed by a fresh tap on the microphone.
    /// The audio engine keeps running, so there's no gap in what's heard.
    private func listen(with recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true // show words as you speak
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true // keep audio on the phone
        }
        self.request = request

        engine.inputNode.removeTap(onBus: 0)
        Self.installTap(on: engine.inputNode, request: request) { [weak self] rms in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                // Speech sits around 0.01 to 0.1 RMS; stretch that to 0...1, then smooth it.
                let target = min(1, Double(rms) * 12)
                self.level = self.level * 0.6 + target * 0.4
            }
        }
        task = Self.startTask(recognizer: recognizer, request: request) { [weak self] text, isDone in
            // Speech calls back on a background thread; hop to the main actor to update the UI.
            Task { @MainActor in self?.handle(text: text, isDone: isDone, from: request) }
        }
    }

    private func handle(text: String?, isDone: Bool, from source: SFSpeechAudioBufferRecognitionRequest) {
        if let text, !text.isEmpty {
            // A fresh transcription after a pause: keep what came before instead of losing it.
            if Self.isRestart(from: current, to: text) { commit() }
            current = text
            emptyRestarts = 0
            transcript = Self.join(committed, current)
        }
        guard isDone else { return }
        commit()
        transcript = committed
        // The recognizer finished on its own (a long pause, or its time limit) while
        // you're still talking: carry on with a new task rather than stopping.
        if isRecording, source === request, let recognizer, emptyRestarts < 3 {
            emptyRestarts += 1
            listen(with: recognizer)
        } else if isRecording, source === request {
            stop()
        }
    }

    private func commit() {
        committed = Self.join(committed, current)
        current = ""
    }

    /// True when the new text isn't a continuation of the old one: it starts
    /// differently and is shorter, which is what a reset after a pause looks like.
    static func isRestart(from old: String, to new: String) -> Bool {
        guard !old.isEmpty, new.count < old.count else { return false }
        let a = old.lowercased(), b = new.lowercased()
        let n = min(a.count, b.count, 12)
        return a.prefix(n) != b.prefix(n)
    }

    static func join(_ a: String, _ b: String) -> String {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + " " + b
    }

    // MARK: - Background-thread helpers
    // These are `nonisolated` because the audio engine and Speech framework call
    // their closures on background threads, not the main thread.

    nonisolated private static func installTap(on input: AVAudioInputNode,
                                               request: SFSpeechAudioBufferRecognitionRequest,
                                               onLevel: @escaping @Sendable (Float) -> Void) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            // Root-mean-square of the samples: a simple measure of loudness.
            if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                let count = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<count { sum += samples[i] * samples[i] }
                onLevel((sum / Float(count)).squareRoot())
            }
        }
    }

    nonisolated private static func startTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }

    nonisolated private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
