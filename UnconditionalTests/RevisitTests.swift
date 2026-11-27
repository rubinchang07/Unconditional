import Foundation
import Testing
import SwiftData
@testable import Unconditional

/// Looking at a reframe again a few days later.
@MainActor
struct RevisitTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func reframe(daysAgo: Double, headAndHeart: Bool = true) -> Reframe {
        let r = Reframe(createdAt: now.addingTimeInterval(-daysAgo * 86_400))
        if headAndHeart { r.headLight = 0.8 }
        return r
    }

    @Test("Offered after three days, not before, and only for head and heart reframes")
    func timing() {
        #expect(!reframe(daysAgo: 1).canRevisit(now: now))
        #expect(reframe(daysAgo: 3).canRevisit(now: now))
        #expect(!reframe(daysAgo: 5, headAndHeart: false).canRevisit(now: now))
    }

    @Test("Describes the change without grading it")
    func messages() {
        #expect(RevisitView.message(then: 0.6, now: 0.1) == "They've come together. Sometimes it just takes time.")
        #expect(RevisitView.message(then: 0.1, now: 0.1) == "Still in tune.")
        #expect(RevisitView.message(then: 0.7, now: 0.4) == "A little closer than before. Still settling, and that's okay.")
        #expect(RevisitView.message(then: 0.4, now: 0.5) == "Still settling. Some things take longer, and that's okay.")
    }

    @Test("The second look survives a backup, and the first is untouched")
    func roundTrip() throws {
        let old = try AppSchema.inMemoryContainer()
        let entry = Entry(kind: .write, text: "I'm behind", createdAt: now)
        old.mainContext.insert(entry)
        let r = reframe(daysAgo: 0)
        r.distressBefore = 8
        r.laterHead = 0.7
        r.laterHeart = 0.6
        r.laterAt = now
        old.mainContext.insert(r)
        entry.reframe = r

        let file = try DataTransfer.encode(DataTransfer.snapshot(from: old.mainContext))
        let new = try AppSchema.inMemoryContainer()
        try DataTransfer.restore(DataTransfer.decode(file), into: new.mainContext)

        let restored = try #require(try new.mainContext.fetch(FetchDescriptor<Reframe>()).first)
        #expect(restored.hasLater)
        #expect(restored.laterHeart == 0.6)
        #expect(restored.distressBefore == 8)
        #expect(restored.headLight == 0.8)
    }
}
