import Foundation
import Testing
import SwiftData
@testable import Unconditional

/// The plain-language summary that Insights opens on.
@MainActor
struct InsightSummaryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    /// A fixed "now", so the tests don't depend on today's date.
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try AppSchema.inMemoryContainer()
    }

    /// An entry `daysAgo` days before now, at `hour` o'clock.
    @discardableResult
    private func entry(_ loop: Loop?, daysAgo: Int, hour: Int = 20, good: Bool = false) -> Entry {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        let entry = Entry(kind: .write, text: "…", createdAt: date)
        context.insert(entry)
        entry.loop = loop
        entry.isGood = good
        return entry
    }

    private func loop(_ name: String) -> Loop {
        let loop = Loop(name: name, coreBelief: "", pattern: "", sortOrder: 0)
        context.insert(loop)
        return loop
    }

    private func sentences() throws -> [String] {
        InsightSummary.sentences(entries: try context.fetch(FetchDescriptor<Entry>()),
                                 reframes: try context.fetch(FetchDescriptor<Reframe>()), now: now)
    }

    @Test("With only a couple of check-ins, it just says more is coming")
    func tooFew() throws {
        entry(nil, daysAgo: 1)
        #expect(try sentences().count == 1)
        #expect(try sentences()[0].hasPrefix("After a few more check-ins"))
    }

    @Test("Names the loop that came up most, and when")
    func topLoop() throws {
        let behind = loop("Falling behind")
        let career = loop("Career indecision")
        entry(behind, daysAgo: 1, hour: 20)
        entry(behind, daysAgo: 3, hour: 19)
        entry(behind, daysAgo: 5, hour: 21)
        entry(career, daysAgo: 2, hour: 9)
        #expect(try sentences().first == "Falling behind came up most this month, usually in the evenings.")
    }

    @Test("Notices when the top loop came up less than the month before")
    func easing() throws {
        let behind = loop("Falling behind")
        for day in [1, 2, 3] { entry(behind, daysAgo: day, hour: 10) }
        for day in [30, 31, 32, 33, 34] { entry(behind, daysAgo: day) }
        #expect(try sentences().first == "Falling behind came up most this month, usually in the mornings, though less than the month before.")
    }

    @Test("Mentions good moments when there aren't reframes to talk about")
    func goodMoments() throws {
        entry(nil, daysAgo: 1)
        entry(nil, daysAgo: 2)
        entry(nil, daysAgo: 3, good: true)
        #expect(try sentences().contains("You also kept some good moments."))
    }

    @Test("Describes reframes without judging them")
    func reframes() throws {
        for day in [1, 2, 3] {
            let e = entry(nil, daysAgo: day)
            let reframe = Reframe(createdAt: e.createdAt)
            reframe.distressBefore = 8
            reframe.distressAfter = 4
            context.insert(reframe)
            e.reframe = reframe
        }
        #expect(try sentences().contains("After reframing, the distress usually eased a little."))
    }

    @Test("Never more than two sentences, and never a score")
    func short() throws {
        let behind = loop("Falling behind")
        for day in 1...10 { entry(behind, daysAgo: day, good: day.isMultiple(of: 2)) }
        let text = try sentences()
        #expect(text.count <= 2)
        #expect(!text.joined().contains("/10"))
        #expect(!text.joined().lowercased().contains("better"))
        #expect(!text.joined().lowercased().contains("worse"))
    }
}

/// Loops drawn as rings.
@MainActor
struct LoopRingTests {
    private func ring(count: Int, previous: Int) -> LoopRing {
        LoopRing(name: "Falling behind", count: count, previous: previous, maxCount: 10, color: .blue)
    }

    @Test("Each time it came up adds a turn, up to seven")
    func turns() {
        #expect(ring(count: 1, previous: 0).turns == 1)
        #expect(ring(count: 4, previous: 0).turns == 4)
        #expect(ring(count: 20, previous: 0).turns == 7)
    }

    @Test("The ring only opens when a loop came up less than before")
    func gap() {
        #expect(ring(count: 5, previous: 0).gap == 0)
        #expect(ring(count: 5, previous: 5).gap == 0)
        #expect(ring(count: 8, previous: 5).gap == 0)
        #expect(ring(count: 4, previous: 5).gap > 0)
        #expect(ring(count: 1, previous: 5).gap > ring(count: 4, previous: 5).gap)
    }

    @Test("Even a fully eased loop keeps most of its ring")
    func gapStaysSmall() {
        #expect(ring(count: 0, previous: 9).gap < Double.pi)
    }
}
