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

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

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

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true // show words as you speak
            request.addsPunctuation = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true // keep audio on the phone
            }
            self.request = request

            transcript = ""
            Self.installTap(on: engine.inputNode, request: request)
            engine.prepare()
            try engine.start()
            isRecording = true

            task = Self.startTask(recognizer: recognizer, request: request) { [weak self] text, isDone in
                // Speech calls back on a background thread; hop to the main actor to update the UI.
                Task { @MainActor in self?.handle(text: text, isDone: isDone) }
            }
        } catch {
            errorMessage = "Couldn't start recording: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio() // lets the recognizer finish the last words
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handle(text: String?, isDone: Bool) {
        if let text { transcript = text }
        if isDone {
            if isRecording { stop() }
            task = nil
        }
    }

    // MARK: - Background-thread helpers
    // These are `nonisolated` because the audio engine and Speech framework call
    // their closures on background threads, not the main thread.

    nonisolated private static func installTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
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
