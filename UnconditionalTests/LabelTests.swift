import Foundation
import Testing
@testable import Unconditional

/// The small pieces of logic that decide what the app says and shows.
@MainActor
struct LabelTests {
    @Test("A win's effort-outcome slider reads as words", arguments: [
        (0.0, "Effort"), (0.3, "Mostly effort"), (0.5, "Effort and outcome"), (0.7, "Mostly outcome"), (1.0, "Outcome"),
    ])
    func effortLabel(value: Double, expected: String) {
        #expect(Win.effortLabel(for: value) == expected)
    }

    @Test("A map link's strength reads as words, never a number", arguments: [
        (0.0, "not linked"), (0.2, "a little"), (0.5, "somewhat"), (0.9, "strongly"),
    ])
    func strengthLabel(value: Double, expected: String) {
        #expect(MapLink.strengthLabel(value) == expected)
    }

    @Test("Only a real urge to quit counts as one")
    func urgeToQuit() {
        let reflection = CareerReflection(moment: .study)
        reflection.urgeToQuit = 2
        #expect(!reflection.hasUrgeToQuit)
        reflection.urgeToQuit = 3
        #expect(reflection.hasUrgeToQuit)
    }
}

/// The orb's shapes and easing, which every animation is built on.
@MainActor
struct OrbTests {
    @Test("Easing starts at 0, ends at 1, and stays inside")
    func easeBounds() {
        #expect(Gooey.ease(-1) == 0)
        #expect(Gooey.ease(0) == 0)
        #expect(Gooey.ease(0.5) == 0.5)
        #expect(Gooey.ease(1) == 1)
        #expect(Gooey.ease(2) == 1)
    }

    @Test("Easing only ever moves forward")
    func easeIsSmooth() {
        let steps = stride(from: 0.0, through: 1.0, by: 0.05).map(Gooey.ease)
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test("The listening orb grows with your voice, the others don't")
    func listeningScales() {
        #expect(OrbState.listening.shape(level: 1).scale > OrbState.listening.shape(level: 0).scale)
        for state in [OrbState.resting, .breathing, .settling, .glowing] {
            #expect(state.shape(level: 0).scale == state.shape(level: 1).scale)
        }
    }

    @Test("Settling after a reframe is the calmest shape")
    func settlingIsCalmest() {
        let calmest = [OrbState.resting, .listening, .breathing, .settling, .glowing]
            .min { $0.shape(level: 0).wobble < $1.shape(level: 0).wobble }
        #expect(calmest == .settling)
    }
}

/// Wins stay at the surface for about two weeks, then settle. Pinned ones stay up.
@MainActor
struct WinSettlingTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func win(_ text: String, daysAgo: Int, pinned: Bool = false) -> Win {
        let win = Win(text: text, createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!)
        win.isPinned = pinned
        return win
    }

    @Test("Recent wins stay at the surface, older ones settle, nothing is dropped")
    func split() {
        let wins = [win("today", daysAgo: 0), win("last week", daysAgo: 7), win("last month", daysAgo: 30)]
        let result = Win.split(wins, now: now)
        #expect(result.surface.map(\.text) == ["today", "last week"])
        #expect(result.settled.map(\.text) == ["last month"])
        #expect(result.surface.count + result.settled.count == wins.count)
    }

    @Test("A pinned win stays at the surface however old, and comes first")
    func pinned() {
        let wins = [win("today", daysAgo: 0), win("the big one", daysAgo: 200, pinned: true)]
        let result = Win.split(wins, now: now)
        #expect(result.surface.map(\.text) == ["the big one", "today"])
        #expect(result.settled.isEmpty)
    }
}
