import Foundation
import Testing
import SwiftData
@testable import Unconditional

/// Choosing your loops in the welcome tour or Settings.
@MainActor
struct LoopStarterTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.inMemoryContainer()
    }

    private func loops() throws -> [Loop] {
        try context.fetch(FetchDescriptor<Loop>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @Test("Starters become loops, each with its own thought reset")
    func startersBringThoughts() throws {
        let picked = Array(LoopStarter.all.prefix(2))
        LoopStarter.add(starters: picked, custom: [], to: context)

        #expect(try loops().map(\.name) == picked.map(\.name))
        let thoughts = try context.fetch(FetchDescriptor<ResetThought>())
        #expect(thoughts.count == 2)
        #expect(thoughts.allSatisfy { $0.loop != nil })
    }

    @Test("Your own loops are trimmed, and blank ones are skipped")
    func customLoops() throws {
        LoopStarter.add(starters: [], custom: ["  Perfectionism ", "", "   "], to: context)
        #expect(try loops().map(\.name) == ["Perfectionism"])
    }

    @Test("Adding a loop you already have doesn't make a second one")
    func noDuplicates() throws {
        let first = LoopStarter.all[0]
        LoopStarter.add(starters: [first], custom: [], to: context)
        LoopStarter.add(starters: [first], custom: [first.name.uppercased(), "Mine", "mine"], to: context)
        #expect(try loops().map(\.name) == [first.name, "Mine"])
    }

    @Test("New loops go after the ones you have")
    func ordering() throws {
        LoopStarter.add(starters: [], custom: ["A"], to: context)
        LoopStarter.add(starters: [], custom: ["B"], to: context)
        #expect(try loops().map(\.sortOrder) == [0, 1])
    }
}
