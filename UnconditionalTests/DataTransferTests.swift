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
        context.insert(PersonalValue(name: "Curiosity", meaning: "Learning for its own sake", createdAt: day))
        context.insert(SavedReminder(text: "You're allowed to rest.", createdAt: day))
        let thought = ResetThought(text: "Everyone is ahead", perspective: "Highlights, not lives", sortOrder: 0)
        context.insert(thought)
        thought.loop = loop
        context.insert(ParkedThought(text: "Should I switch majors?", createdAt: day))
        context.insert(TinyStep(text: "Email one person", createdAt: day))
        let career = CareerReflection(moment: .interview, topic: "Internship", createdAt: day)
        career.enjoyment = 7
        context.insert(career)
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

        #expect(summary == .init(added: 10, skipped: 0))
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
    }

    @Test("Restoring the same file twice adds nothing the second time")
    func restoreIsSafeToRepeat() throws {
        let context = oldPhone.mainContext
        try fill(context)
        let snapshot = try DataTransfer.decode(DataTransfer.encode(DataTransfer.snapshot(from: context)))

        let summary = DataTransfer.restore(snapshot, into: context)
        #expect(summary.added == 0)
        #expect(try count(Entry.self, in: context) == 2)
        #expect(try count(Loop.self, in: context) == 1)
    }

    @Test("A loop with the same name is reused, not doubled")
    func loopsMatchByName() throws {
        let old = oldPhone.mainContext
        try fill(old)
        let snapshot = DataTransfer.snapshot(from: old)

        let new = newPhone.mainContext
        new.insert(Loop(name: "falling BEHIND", coreBelief: "", pattern: "", sortOrder: 0))
        DataTransfer.restore(snapshot, into: new)

        #expect(try count(Loop.self, in: new) == 1)
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
