import Testing
@testable import Unconditional

/// Speaking keeps every word, even when the recognizer starts over after a pause.
@MainActor
struct SpeechTests {
    @Test("Growing text is a continuation, not a restart")
    func continuation() {
        #expect(!VoiceRecorder.isRestart(from: "I feel", to: "I feel behind"))
        #expect(!VoiceRecorder.isRestart(from: "", to: "anything"))
    }

    @Test("Shorter text that starts differently is a fresh start after a pause")
    func restart() {
        #expect(VoiceRecorder.isRestart(from: "I feel behind everyone today", to: "and tired"))
    }

    @Test("A small revision isn't mistaken for a restart")
    func revision() {
        #expect(!VoiceRecorder.isRestart(from: "I feel behind every one", to: "I feel behind everyone"))
    }

    @Test("Pieces join with one space")
    func join() {
        #expect(VoiceRecorder.join("", "hi") == "hi")
        #expect(VoiceRecorder.join("hi", "") == "hi")
        #expect(VoiceRecorder.join("I feel behind", "and tired") == "I feel behind and tired")
    }
}
