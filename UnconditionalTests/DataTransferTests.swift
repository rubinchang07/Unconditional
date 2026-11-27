import Foundation
import Testing
import SwiftData
@testable import Unconditional

/// Export and restore: the one place where losing data would really hurt.
@MainActor
struct DataTransferTests {
    /// Whole seconds, since an export keeps dates to the second.
    let day = Date(timeIntervalSince1970: 1_790_000_000)

    private func fill(_ context: ModelContext) throws {
        let loop = Loop(name: "Falling behind", coreBelief: "I'm late.", pattern: "", sortOrder: 0)
        context.insert(loop)

        let entry = Entry(kind: .write, text: "Saw a friend's offer and spiraled.", createdAt: day)
        context.insert(entry)
        entry.loop = loop
        entry.compassionShared = "Lots of people feel this."
        let reframe = Reframe(trigger: "Their offer", coreBelief: "I'm behind", kinderRead: "Different timelines", createdAt: day)
        reframe.distressBefore = 8
        reframe.distressAfter = 4
        context.insert(reframe)
        entry.reframe = reframe

        let good = Entry(kind: .draw, drawingData: Data([1, 2, 3]), createdAt: day.addingTimeInterval(60))
        context.insert(good)
        good.isGood = true

        context.insert(Win(text: "Finished the problem set", effortToOutcome: 0.2, createdAt: day))
        let curiosity = PersonalValue(name: "Curiosity", meaning: "Learning for its own sake", createdAt: day)
        context.insert(curiosity)
        let career = Loop(name: "Career indecision", coreBelief: "", pattern: "", sortOrder: 1)
        context.insert(career)

        // Two map links: loop to loop, and loop to value (turned down).
        let loops = MapLink()
        context.insert(loops)
        loops.loopA = loop
        loops.loopB = career
        loops.strength = 0.8
        let toValue = MapLink()
        context.insert(toValue)
        toValue.loopA = loop
        toValue.value = curiosity
        toValue.status = "dismissed"
        context.insert(SavedReminder(text: "You're allowed to rest.", createdAt: day))
        context.insert(GroundingPhoto(imageData: Data([9, 8, 7]), isCutout: true, caption: "The lake", createdAt: day))
        let thought = ResetThought(text: "Everyone is ahead", perspective: "Highlights, not lives", sortOrder: 0)
        context.insert(thought)
        thought.loop = loop
        context.insert(ParkedThought(text: "Should I switch majors?", createdAt: day))
        context.insert(TinyStep(text: "Email one person", createdAt: day))
        let reflection = CareerReflection(moment: .interview, topic: "Internship", createdAt: day)
        reflection.enjoyment = 7
        context.insert(reflection)
        try context.save()
    }

    /// Two throwaway databases: the old phone and the new one.
    /// Swift Testing makes a fresh copy of this struct for every test.
    let oldPhone: ModelContainer
    let newPhone: ModelContainer

    init() throws {
        oldPhone = try AppSchema.inMemoryContainer()
        newPhone = try AppSchema.inMemoryContainer()
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test("Everything comes back after export and restore on a new phone")
    func roundTrip() throws {
        let old = oldPhone.mainContext
        try fill(old)
        let file = try DataTransfer.encode(DataTransfer.snapshot(from: old))

        let new = newPhone.mainContext
        let summary = DataTransfer.restore(try DataTransfer.decode(file), into: new)

        #expect(summary == .init(added: 14, skipped: 0))
        #expect(try count(Entry.self, in: new) == 2)
        #expect(try count(Reframe.self, in: new) == 1)
        #expect(try count(CareerReflection.self, in: new) == 1)

        let entries = try new.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt)]))
        #expect(entries[0].loop?.name == "Falling behind")
        #expect(entries[0].reframe?.distressAfter == 4)
        #expect(entries[0].compassionShared == "Lots of people feel this.")
        #expect(entries[1].isGood)
        #expect(entries[1].drawingData == Data([1, 2, 3]))

        let thought = try #require(try new.fetch(FetchDescriptor<ResetThought>()).first)
        #expect(thought.loop?.name == "Falling behind")

        let photo = try #require(try new.fetch(FetchDescriptor<GroundingPhoto>()).first)
        #expect(photo.imageData == Data([9, 8, 7]))
        #expect(photo.isCutout)
        #expect(photo.caption == "The lake")

        // Your map comes back too, including the link you turned down.
        let links = try new.fetch(FetchDescriptor<MapLink>())
        let loopLink = try #require(links.first { $0.loopB != nil })
        #expect(Set([loopLink.loopA?.name, loopLink.loopB?.name]) == ["Falling behind", "Career indecision"])
        #expect(loopLink.strength == 0.8)
        let valueLink = try #require(links.first { $0.value != nil })
        #expect(valueLink.value?.name == "Curiosity")
        #expect(!valueLink.isConfirmed)
    }

    @Test("Files from before map links were exported still open")
    func olderFile() throws {
        var snapshot = try DataTransfer.snapshot(from: oldPhone.mainContext)
        snapshot.mapLinks = nil
        snapshot.photos = nil
        let text = String(decoding: try DataTransfer.encode(snapshot), as: UTF8.self)
        #expect(!text.contains("mapLinks"))
        #expect(throws: Never.self) { try DataTransfer.decode(Data(text.utf8)) }
    }

    @Test("Restoring the same file twice adds nothing the second time")
    func restoreIsSafeToRepeat() throws {
        let context = oldPhone.mainContext
        try fill(context)
        let snapshot = try DataTransfer.decode(DataTransfer.encode(DataTransfer.snapshot(from: context)))

        let summary = DataTransfer.restore(snapshot, into: context)
        #expect(summary.added == 0)
        #expect(try count(Entry.self, in: context) == 2)
        #expect(try count(Loop.self, in: context) == 2)
        #expect(try count(MapLink.self, in: context) == 2)
        #expect(try count(GroundingPhoto.self, in: context) == 1)
    }

    @Test("One-step-at-a-time paths come back with their footprints, once")
    func pathsRoundTrip() throws {
        let old = oldPhone.mainContext
        let path = StepPath(title: "Finding a job", createdAt: day)
        old.insert(path)
        for (i, text) in ["Opened the job board", "Sent one email"].enumerated() {
            let step = Footstep(text: text, createdAt: day.addingTimeInterval(Double(i) * 3600))
            old.insert(step)
            step.path = path
        }
        let file = try DataTransfer.encode(DataTransfer.snapshot(from: old))

        let new = newPhone.mainContext
        _ = DataTransfer.restore(try DataTransfer.decode(file), into: new)
        _ = DataTransfer.restore(try DataTransfer.decode(file), into: new)

        let paths = try new.fetch(FetchDescriptor<StepPath>())
        #expect(paths.count == 1)
        #expect(paths.first?.walked.map(\.text) == ["Opened the job board", "Sent one email"])
    }

    @Test("Hard days on a path, how an entry sat, and laughs all come back")
    func newerThingsRoundTrip() throws {
        let old = oldPhone.mainContext
        let path = StepPath(title: "Finding a job", createdAt: day)
        old.insert(path)
        let step = Footstep(text: "Sent one email", createdAt: day)
        old.insert(step)
        step.path = path
        let tide = Footstep(text: "Got a rejection", createdAt: day.addingTimeInterval(3600))
        tide.isTide = true
        tide.heaviness = 0.8
        tide.learned = "One no isn't the answer."
        old.insert(tide)
        tide.path = path
        step.shell = "music on"
        path.setNext("Open the job board", now: day)

        let entry = Entry(kind: .words, text: "tired (heavier, a lot)", createdAt: day)
        old.insert(entry)
        entry.lightness = 0.2
        old.insert(Laugh(text: "The cat sat on my homework", imageData: Data([9, 9]), createdAt: day))
        let placed = PersonalValue(name: "Patience", meaning: "", createdAt: day)
        old.insert(placed)
        placed.mapX = 0.25
        placed.mapY = 0.75

        let file = try DataTransfer.encode(DataTransfer.snapshot(from: old))
        let new = newPhone.mainContext
        _ = DataTransfer.restore(try DataTransfer.decode(file), into: new)
        _ = DataTransfer.restore(try DataTransfer.decode(file), into: new)

        let restored = try #require(try new.fetch(FetchDescriptor<StepPath>()).first)
        #expect(restored.walked.map(\.text) == ["Sent one email"])
        #expect(restored.tides.count == 1)
        #expect(restored.tides.first?.heaviness == 0.8)
        #expect(restored.tides.first?.learned == "One no isn't the answer.")
        #expect(restored.walked.first?.shell == "music on")
        #expect(restored.nextStep == "Open the job board")
        #expect(restored.nextSetAt == day)
        let entries = try new.fetch(FetchDescriptor<Entry>())
        #expect(entries.first?.kind == .words)
        #expect(entries.first?.lightness == 0.2)
        let value = try #require(try new.fetch(FetchDescriptor<PersonalValue>()).first { $0.name == "Patience" })
        #expect(value.mapX == 0.25 && value.mapY == 0.75)
        let laughs = try new.fetch(FetchDescriptor<Laugh>())
        #expect(laughs.count == 1)
        #expect(laughs.first?.imageData == Data([9, 9]))
    }

    @Test("A file from before tides and laughs still opens")
    func olderFileWithoutNewFields() throws {
        let json = """
        {"version":1,"exportedAt":"2026-11-01T00:00:00Z","loops":[],"wins":[],"values":[],"reminders":[],
         "resetThoughts":[],"parkedThoughts":[],"tinySteps":[],"careerReflections":[],
         "entries":[{"createdAt":"2026-11-01T00:00:00Z","kind":"write","text":"hi","drawingBackground":"paper",
                     "isGood":false,"compassionHard":"","compassionShared":"","compassionNeed":""}],
         "paths":[{"title":"A path","createdAt":"2026-11-01T00:00:00Z","isResting":false,
                   "steps":[{"text":"One step","createdAt":"2026-11-01T00:00:00Z"}]}]}
        """
        let snapshot = try DataTransfer.decode(Data(json.utf8))
        let new = newPhone.mainContext
        DataTransfer.restore(snapshot, into: new)
        #expect(try new.fetch(FetchDescriptor<Entry>()).first?.lightness == nil)
        #expect(try new.fetch(FetchDescriptor<StepPath>()).first?.walked.count == 1)
    }

    @Test("A loop with the same name is reused, not doubled")
    func loopsMatchByName() throws {
        let old = oldPhone.mainContext
        try fill(old)
        let snapshot = try DataTransfer.snapshot(from: old)

        let new = newPhone.mainContext
        new.insert(Loop(name: "falling BEHIND", coreBelief: "", pattern: "", sortOrder: 0))
        DataTransfer.restore(snapshot, into: new)

        #expect(try count(Loop.self, in: new) == 2)
        let entry = try #require(try new.fetch(FetchDescriptor<Entry>()).first { $0.loop != nil })
        #expect(entry.loop?.name == "falling BEHIND")
    }

    @Test("A file that isn't an export is refused, not half-read")
    func badFile() {
        #expect(throws: (any Error).self) {
            try DataTransfer.decode(Data("{\"hello\": 1}".utf8))
        }
    }

    @Test("The file is readable JSON with a version")
    func readableFile() throws {
        let context = oldPhone.mainContext
        try fill(context)
        let text = String(decoding: try DataTransfer.encode(DataTransfer.snapshot(from: context)), as: UTF8.self)
        #expect(text.contains("\"version\" : 1"))
        #expect(text.contains("Saw a friend's offer and spiraled."))
    }
}
