import Foundation
import SwiftUI
import Testing
@testable import Unconditional

/// Words: feeling words offered after a slide, and how kept words are written down.
@MainActor
struct FeelingWordsTests {
    @Test("Sliding heavier offers heavier words, and lighter offers lighter ones")
    func sideMatchesSlide() {
        let heavy = FeelingWords.related(to: "tired", leaning: -0.7)
        let light = FeelingWords.related(to: "tired", leaning: 0.7)
        #expect(heavy.count == 6)
        #expect(heavy.allSatisfy(FeelingWords.heavy.contains))
        #expect(light.allSatisfy(FeelingWords.light.contains))
        #expect(!heavy.contains("tired"))
    }

    @Test("Words you already kept aren't offered again, and 'show others' changes them")
    func excludesAndShuffles() {
        let used: Set = ["sad", "lonely", "stuck"]
        let first = FeelingWords.related(to: "down", leaning: -0.5, excluding: used)
        #expect(first.allSatisfy { !used.contains($0) })
        let next = FeelingWords.related(to: "down", leaning: -0.5, excluding: used, shuffle: 1)
        #expect(Set(first) != Set(next))
    }

    @Test("A small slide is in between, and offers both sides")
    func inBetween() {
        #expect(FeelingWords.describe(0.05) == "in between")
        let both = FeelingWords.related(to: "okay", leaning: 0, count: 12)
        #expect(both.contains(where: FeelingWords.heavy.contains))
        #expect(both.contains(where: FeelingWords.light.contains))
    }

    @Test("How far you slide is written in plain words")
    func describe() {
        #expect(FeelingWords.describe(-0.3) == "heavier, a little")
        #expect(FeelingWords.describe(0.6) == "lighter, quite")
        #expect(FeelingWords.describe(-1) == "heavier, a lot")
    }

    @Test("Kept words become one line of the entry, and lean on average")
    func compose() {
        let words = [KeptWord(word: "tired", lean: -0.9), KeptWord(word: "hopeful", lean: 0.3)]
        #expect(FeelingWords.compose(words) == "tired (heavier, a lot) · hopeful (lighter, a little)")
        #expect(abs(FeelingWords.averageLean(words) - -0.3) < 0.0001)
        #expect(FeelingWords.averageLean([]) == 0)
    }

    @Test("Only the first typed word is used, tidied")
    func firstWord() {
        #expect(FeelingWords.firstWord(of: "  Tired, really tired ") == "tired")
        #expect(FeelingWords.firstWord(of: "   ") == nil)
    }
}

/// One check-in for every kind of moment.
@MainActor
struct CheckInTests {
    @Test("Hard and good starting points are both offered, taking turns")
    func promptsMixed() {
        let mixed = SituationPrompts.mixed
        #expect(mixed.count == SituationPrompts.all.count + SituationPrompts.goodOnes.count)
        #expect(mixed[0].title == SituationPrompts.all[0].title)
        #expect(mixed[1].title == SituationPrompts.goodOnes[0].title)
        #expect(Set(mixed.map(\.id)).count == mixed.count)
    }

    @Test("Words is a text kind of entry")
    func wordsIsText() {
        #expect(EntryKind.words.isText)
        #expect(EntryKind.allCases.count == 4)
    }
}

/// A hard day on a path: the tide comes in and goes out.
@MainActor
struct TideTests {
    @Test("The tide rises with how hard it felt, but never covers the whole screen")
    func reach() {
        #expect(Footstep.tideReach(heaviness: 0) < Footstep.tideReach(heaviness: 1))
        #expect(Footstep.tideReach(heaviness: 5) == Footstep.tideReach(heaviness: 1))
        #expect(Footstep.tideReach(heaviness: 1) < 0.7)
    }

    @Test("It comes in, holds, and goes back out completely")
    func surge() {
        #expect(SandBackground.surge(elapsed: 0) == 0)
        #expect(SandBackground.surge(elapsed: 2) == 1)
        #expect(SandBackground.surge(elapsed: 4) > 0)
        #expect(SandBackground.surge(elapsed: 4) < 1)
        #expect(SandBackground.surge(elapsed: SandBackground.surgeDuration) == 0)
    }
}

/// Make it silly.
@MainActor
struct SillyThoughtTests {
    @Test("The thought reads naturally after “I'm having the thought that”")
    func lowercasedFirst() {
        #expect(SillyThoughtView.lowercasedFirst("Everyone is ahead of me") == "everyone is ahead of me")
        #expect(SillyThoughtView.lowercasedFirst("I always mess up") == "I always mess up")
        #expect(SillyThoughtView.lowercasedFirst("I'm behind") == "I'm behind")
    }
}
