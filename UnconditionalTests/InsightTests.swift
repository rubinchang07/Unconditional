import Foundation
import Testing
import SwiftData
import SwiftUI
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

/// Values on the map spread out so their labels don't overlap.
@MainActor
struct MapLayoutTests {
    @Test("Values never overlap, however many there are")
    func noOverlap() {
        let values = (1...9).map { PersonalValue(name: "Value \($0)") }
        let center = CGPoint(x: 180, y: 180)
        let points = MapLayout.spread(values: values, loops: [], links: [], center: center, outer: 134)
        #expect(points.count == values.count)
        for i in points.indices {
            for j in points.indices where j > i {
                let widths = MapLayout.valueSize(values[i].name).width + MapLayout.valueSize(values[j].name).width
                let apartX = abs(points[i].x - points[j].x) >= widths / 2 - 1
                let apartY = abs(points[i].y - points[j].y) >= MapLayout.labelHeight - 1
                #expect(apartX || apartY, "Value \(i + 1) and \(j + 1) overlap")
            }
        }
    }

    @Test("Values keep clear of loop labels and of values you've moved")
    func avoidsLoopsAndPlacedValues() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext
        let loops = ["Self-worth", "Career", "Falling behind"].enumerated().map { i, name in
            let loop = Loop(name: name, coreBelief: "", pattern: "", sortOrder: i)
            context.insert(loop)
            return loop
        }
        let values = (1...4).map { PersonalValue(name: "Value \($0)") }
        values.forEach(context.insert)
        // One value you've placed yourself, just right of the middle.
        values[0].mapX = 0.2
        values[0].mapY = 0
        let center = CGPoint(x: 180, y: 180)
        let outer: CGFloat = 134
        let points = MapLayout.spread(values: values, loops: loops, links: [], center: center, outer: outer)

        #expect(points[0] == CGPoint(x: center.x + 0.2 * outer, y: center.y))
        func rect(_ p: CGPoint, _ size: CGSize) -> CGRect {
            CGRect(x: p.x - size.width / 2, y: p.y - size.height / 2, width: size.width, height: size.height)
        }
        for (i, point) in points.enumerated() {
            for (j, loop) in loops.enumerated() {
                let angle = -Double.pi / 2 + 2 * Double.pi * Double(j) / Double(loops.count)
                let spot = CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle))
                let shared = rect(point, MapLayout.valueSize(values[i].name)).intersection(rect(spot, MapLayout.loopBox(loop)))
                #expect(shared.isNull || shared.width * shared.height < 1, "Value \(i + 1) sits on \(loop.name)")
            }
            for j in points.indices where j > i {
                let shared = rect(point, MapLayout.valueSize(values[i].name))
                    .intersection(rect(points[j], MapLayout.valueSize(values[j].name)))
                #expect(shared.isNull || shared.width * shared.height < 1, "Value \(i + 1) and \(j + 1) overlap")
            }
        }
    }

    @Test("A map with no size yet doesn't crash")
    func zeroSize() {
        let values = (1...3).map { PersonalValue(name: "Value \($0)") }
        let points = MapLayout.spread(values: values, loops: [], links: [], center: .zero, outer: -46)
        #expect(points.count == 3)
    }

    @Test("A value dragged outside the map is kept inside it")
    func clamp() {
        let center = CGPoint(x: 100, y: 100)
        let spot = MapLayout.clamp(CGPoint(x: 400, y: 100), center: center, limit: 80)
        #expect(spot == CGPoint(x: 180, y: 100))
        #expect(MapLayout.clamp(CGPoint(x: 120, y: 100), center: center, limit: 80) == CGPoint(x: 120, y: 100))
    }
}

/// Which loops fit on the map.
@MainActor
struct VisibleLoopsTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.inMemoryContainer()
    }

    private func loops(_ count: Int) -> [Loop] {
        (0..<count).map { i in
            let loop = Loop(name: "Loop \(i)", coreBelief: "", pattern: "", sortOrder: i)
            context.insert(loop)
            return loop
        }
    }

    @Test("A few loops all show")
    func fewLoops() {
        let all = loops(5)
        #expect(MapLayout.visibleLoops(all, links: []) == all)
    }

    @Test("With many loops, the busiest show, in your order")
    func busiest() {
        let all = loops(10)
        for loop in all.suffix(2) {
            let entry = Entry(kind: .write, text: "…")
            context.insert(entry)
            entry.loop = loop
        }
        let shown = MapLayout.visibleLoops(all, links: [])
        #expect(shown.count == MapLayout.loopLimit)
        #expect(shown.contains(all[9]) && shown.contains(all[8]))
        #expect(shown.map(\.sortOrder) == shown.map(\.sortOrder).sorted())
    }

    @Test("A loop you linked always shows, even if it's quiet")
    func linkedStays() {
        let all = loops(10)
        let link = MapLink()
        context.insert(link)
        link.loopA = all[9]
        link.loopB = all[8]
        let shown = MapLayout.visibleLoops(all, links: [link])
        #expect(shown.contains(all[9]) && shown.contains(all[8]))
        #expect(shown.count == MapLayout.loopLimit)
    }
}

/// Seeing the map at an angle.
struct MapProjectorTests {
    let center = CGPoint(x: 100, y: 100)

    @Test("Flat and unturned, the map is exactly as laid out")
    func flatIsIdentity() {
        let flat = MapProjector(center: center, outer: 80, tilt: 0, spin: 0)
        let p = CGPoint(x: 140, y: 60)
        #expect(flat.project(p) == p)
        #expect(flat.scale(at: p) == 1)
    }

    @Test("Leaned back, the far side is smaller and the near side bigger")
    func perspective() {
        let tilted = MapProjector(center: center, outer: 80, tilt: 0.8, spin: 0)
        let far = CGPoint(x: 100, y: 20), near = CGPoint(x: 100, y: 180)
        #expect(tilted.scale(at: far) < 1)
        #expect(tilted.scale(at: near) > 1)
        #expect(tilted.clarity(tilted.scale(at: far)) < 1)
        #expect(tilted.clarity(tilted.scale(at: near)) == 1)
    }

    @Test("A drag on screen moves a value the same way on a turned map")
    func dragFollowsFinger() {
        let turned = MapProjector(center: center, outer: 80, tilt: 0, spin: 0.9)
        let start = CGPoint(x: 120, y: 90)
        let move = CGSize(width: 15, height: -10)
        let delta = turned.planeDelta(move)
        let moved = turned.project(CGPoint(x: start.x + delta.width, y: start.y + delta.height))
        let before = turned.project(start)
        #expect(abs(moved.x - before.x - move.width) < 0.001)
        #expect(abs(moved.y - before.y - move.height) < 0.001)
    }
}

/// Footprints soften with time but never vanish.
struct FootstepTests {
    @Test("A new print is crisp and an old one stays visible")
    func softness() {
        #expect(Footstep.softness(age: 0) == 1)
        #expect(Footstep.softness(age: 15) < 1)
        #expect(Footstep.softness(age: 400) == Footstep.softness(age: 30))
        #expect(Footstep.softness(age: 400) > 0.5)
    }
}

/// Value labels on the map fit their words.
struct ValueLabelTests {
    @Test("Short words get small capsules, long ones are shortened")
    func sizes() {
        #expect(MapLayout.valueSize("Rest").width < MapLayout.valueSize("Independence").width)
        #expect(MapLayout.shortName("A very long value name indeed").count == MapLayout.nameLimit)
        #expect(MapLayout.shortName("Courage") == "Courage")
    }
}

/// The welcome tour's values, and the sun at the middle of the map.
@MainActor
struct StartingValuesTests {
    @Test("Picked values are added once, skipping ones you already have")
    func addsOnce() throws {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext
        context.insert(PersonalValue(name: "Curiosity"))
        let existing = try context.fetch(FetchDescriptor<PersonalValue>())
        ValueChooser.add(["curiosity", "Rest", "Courage"], existing: existing, to: context)
        let names = try context.fetch(FetchDescriptor<PersonalValue>()).map(\.name).sorted()
        #expect(names == ["Courage", "Curiosity", "Rest"])
    }

    @Test("A single value never sits on the sun")
    func clearOfSun() {
        let center = CGPoint(x: 180, y: 180)
        let point = MapLayout.spread(values: [PersonalValue(name: "Rest")], loops: [], links: [],
                                     center: center, outer: 134)[0]
        let sun = CGRect(x: center.x - MapLayout.sunSize.width / 2, y: center.y - MapLayout.sunSize.height / 2,
                         width: MapLayout.sunSize.width, height: MapLayout.sunSize.height)
        let size = MapLayout.valueSize("Rest")
        let label = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        #expect(!label.intersects(sun.insetBy(dx: 1, dy: 1)))
    }
}
