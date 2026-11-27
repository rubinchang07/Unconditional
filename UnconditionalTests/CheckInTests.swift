import Foundation
import SwiftUI
import Testing
import SwiftData
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

    @Test("A little heavier and a lot heavier offer different words")
    func strengths() {
        let little = FeelingWords.related(to: "tired", leaning: -0.3)
        let lot = FeelingWords.related(to: "tired", leaning: -0.9)
        #expect(little.allSatisfy(FeelingWords.heavyMild.contains))
        #expect(lot.allSatisfy(FeelingWords.heavyStrong.contains))
        #expect(Set(little).isDisjoint(with: lot))
        #expect(Set(FeelingWords.light).count == FeelingWords.light.count)
        #expect(Set(FeelingWords.heavy).count == FeelingWords.heavy.count)
    }

    @Test("Each bubble looks a little different, and the same word always looks the same")
    func shades() {
        let a = FeelingWords.bubbleShade(index: 0, word: "calm")
        let b = FeelingWords.bubbleShade(index: 1, word: "warm")
        #expect(a.hue != b.hue)
        #expect(FeelingWords.bubbleShade(index: 0, word: "calm").hue == a.hue)
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

    @Test("Kept words can be read back from the entry")
    func parse() {
        let words = [KeptWord(word: "tired", lean: -0.9), KeptWord(word: "cared for", lean: 0.6), KeptWord(word: "meh", lean: 0)]
        let back = FeelingWords.parse(FeelingWords.compose(words))
        #expect(back.map(\.word) == ["tired", "cared for", "meh"])
        #expect(back.map(\.lean) == [-0.9, 0.6, 0])
        #expect(FeelingWords.parse("Just some writing").isEmpty)
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

    @Test("A print is dry above the water and wet below it")
    func wetness() {
        #expect(WashablePrint.wetness(printY: 100, waterY: 300) == 0)
        #expect(WashablePrint.wetness(printY: 330, waterY: 300) == 0.5)
        #expect(WashablePrint.wetness(printY: 900, waterY: 300) == 1)
    }
}

/// Reflect, on your mind lately, and the map's sun.
@MainActor
struct ReflectTests {
    @Test("The sun only grows, and fills out over time")
    func sunGrows() {
        #expect(SunGrowth.amount(checkIns: 0, threads: 0) == 0)
        #expect(SunGrowth.amount(checkIns: 10, threads: 0) < SunGrowth.amount(checkIns: 10, threads: 2))
        #expect(SunGrowth.amount(checkIns: 1000, threads: 50) == 1)
        var last = -1.0
        for n in 0...200 {
            let g = SunGrowth.amount(checkIns: n, threads: 0)
            #expect(g >= last)
            last = g
        }
    }

    @Test("Loops compare this month with the month before, in plain words")
    func trends() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let loop = Loop(name: "Falling behind", coreBelief: "", pattern: "", sortOrder: 0)
        context.insert(loop)
        for days in [1.0, 2, 40, 41, 42, 43] {
            let entry = Entry(kind: .write, text: "x", createdAt: now.addingTimeInterval(-days * 86_400))
            context.insert(entry)
            entry.loop = loop
        }
        let good = Entry(kind: .write, text: "nice", createdAt: now.addingTimeInterval(-86_400))
        context.insert(good)
        good.isGood = true

        let trends = LoopTrend.trends(entries: try context.fetch(FetchDescriptor<Entry>()), loops: [loop], now: now)
        let falling = try #require(trends.first { !$0.isGood })
        #expect(falling.recent == 2)
        #expect(falling.before == 4)
        #expect(falling.sentence == "Falling behind came up less than the month before.")
        #expect(trends.contains { $0.isGood && $0.recent == 1 })
        #expect(LoopTrend.headline(trends) == falling)
    }

    @Test("Entries are grouped by month, newest first")
    func months() {
        let calendar = Calendar(identifier: .gregorian)
        let a = Entry(kind: .write, text: "a", createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        let b = Entry(kind: .write, text: "b", createdAt: Date(timeIntervalSince1970: 1_790_000_000 - 40 * 86_400))
        let months = BranchMonth.group([b, a], calendar: calendar)
        #expect(months.count == 2)
        #expect(months.first?.entries.first?.text == "a")
    }

    @Test("With many values, names show only when lit or in use")
    func quietValues() {
        #expect(MapLayout.showsValueName(count: 3, lit: false, active: false))
        #expect(!MapLayout.showsValueName(count: 9, lit: false, active: false))
        #expect(MapLayout.showsValueName(count: 9, lit: true, active: false))
        #expect(MapLayout.showsValueName(count: 9, lit: false, active: true))
    }

    @Test("Sunday is the day for the look-back")
    func sunday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let sunday = Date(timeIntervalSince1970: 1_795_910_400) // 2026-11-29
        #expect(ReminderScheduler.isReviewDay(sunday, calendar: calendar))
        #expect(!ReminderScheduler.isReviewDay(sunday.addingTimeInterval(86_400), calendar: calendar))
    }
}

/// I'm spiraling: breathing, floating words.
@MainActor
struct SpiralingTests {
    @Test("A breath fills over four seconds and empties over six")
    func breath() {
        #expect(ResetWords.breath(at: 0) == 0)
        #expect(ResetWords.breath(at: 4) == 1)
        #expect(ResetWords.breath(at: 7) > 0 && ResetWords.breath(at: 7) < 1)
        #expect(ResetWords.breath(at: 10) == 0)
    }

    @Test("Your loops float first, then words that don't overlap them, nine at most")
    func pool() {
        let words = ResetWords.pool(loops: ["Falling behind", "Wasted effort"])
        #expect(words.first == "falling behind")
        #expect(Set(words).count == words.count)
        #expect(words.count <= 9)
        // "wasted time" shares a word with a loop, so it stays out.
        #expect(!words.contains("wasted time"))
    }

    @Test("Floating words stay fully on screen and never sit on each other")
    func homes() {
        let size = CGSize(width: 350, height: 420)
        let words = ResetWords.pool(loops: ["Career indecision", "Not good enough", "Comparing myself"])
        let spots = ResetWords.homes(for: words, in: size)
        let boxes = zip(words, spots).map { word, p in
            CGRect(x: p.x - ResetWords.width(of: word) / 2, y: p.y - 18, width: ResetWords.width(of: word), height: 36)
        }
        for box in boxes {
            #expect(box.minX >= 0 && box.maxX <= size.width)
        }
        for i in boxes.indices {
            for j in boxes.indices where j > i {
                #expect(!boxes[i].intersects(boxes[j]))
            }
        }
    }
}
