import Foundation
import SwiftData

/// Export everything to one JSON file, and restore from one.
///
/// Everything stays on this phone unless you export it. An export is a plain,
/// readable file you control: keep it as a backup, move it to a new phone, or
/// just look at it. Restoring adds what's in the file and skips anything you
/// already have, so it never overwrites or deletes.
enum DataTransfer {
    /// Bumped if the file's shape ever changes, so older files can still be read.
    static let version = 1

    // MARK: - The file's shape

    struct Snapshot: Codable {
        var version = DataTransfer.version
        var exportedAt = Date.now
        var loops: [LoopRecord] = []
        var entries: [EntryRecord] = []
        var wins: [WinRecord] = []
        var values: [ValueRecord] = []
        var reminders: [ReminderRecord] = []
        var resetThoughts: [ResetThoughtRecord] = []
        var parkedThoughts: [ParkedRecord] = []
        var tinySteps: [TinyStepRecord] = []
        var careerReflections: [CareerRecord] = []
        /// Optional so files exported before map links were included still open.
        var mapLinks: [MapLinkRecord]? = []
        /// Optional for the same reason. Images are stored as base64 text.
        var photos: [PhotoRecord]? = []
        /// "One step at a time" paths, each with its footsteps. Optional for older files.
        var paths: [PathRecord]? = []
        /// Things that made you laugh. Optional for older files.
        var laughs: [LaughRecord]? = []
    }

    struct LaughRecord: Codable {
        var text: String
        var imageData: Data?
        var createdAt: Date
    }

    struct PathRecord: Codable {
        var title: String
        var createdAt: Date
        var isResting: Bool
        var steps: [StepRecord]
        /// The faint next print. Optional, so older files still open.
        var nextStep: String?
        var nextSetAt: Date?
    }

    struct StepRecord: Codable {
        var text: String
        var createdAt: Date
        /// A hard day rather than a step. All three are optional, so older files still open.
        var isTide: Bool?
        var heaviness: Double?
        var learned: String?
        /// What helped with this step. Optional for older files.
        var shell: String?
    }

    struct PhotoRecord: Codable {
        var imageData: Data
        var isCutout: Bool
        var caption: String
        var createdAt: Date
    }

    /// A link on your map. Loops and values are named, since they're matched by name on restore.
    struct MapLinkRecord: Codable {
        var loopA: String?
        var loopB: String?
        var value: String?
        var strength: Double
        var status: String
        var createdAt: Date
    }

    struct LoopRecord: Codable {
        var name: String
        var coreBelief: String
        var pattern: String
        var sortOrder: Int
    }

    struct ReframeRecord: Codable {
        var trigger: String
        var coreBelief: String
        var evidenceFor: String
        var evidenceAgainst: String
        var kinderRead: String
        var smallStep: String
        var createdAt: Date
        var distressBefore: Double
        var distressAfter: Double
        var beliefBefore: Double
        var beliefAfter: Double
        /// Head and heart. Optional, so older files still open.
        var headTrue: Double? = nil
        var headLight: Double? = nil
        /// The second look, a few days later. Optional, so older files still open.
        var laterHead: Double? = nil
        var laterHeart: Double? = nil
        var laterAt: Date? = nil
    }

    struct EntryRecord: Codable {
        var createdAt: Date
        var kind: EntryKind
        var text: String
        /// The drawing, if any. JSON stores it as base64 text.
        var drawingData: Data?
        var drawingBackground: String
        /// The loop's name, since loops are matched by name on restore.
        var loop: String?
        var isGood: Bool
        /// "How does this sit?", 0 heavy to 1 light. Optional, also for older files.
        var lightness: Double?
        var compassionHard: String
        var compassionShared: String
        var compassionNeed: String
        var reframe: ReframeRecord?
    }

    struct WinRecord: Codable {
        var createdAt: Date
        var text: String
        var meaning: String
        var effortToOutcome: Double
        /// Optional so older files still open.
        var isPinned: Bool?
    }

    struct ValueRecord: Codable {
        var name: String
        var meaning: String
        var livedLately: Double
        var createdAt: Date
        /// Where you placed it on your map, if you moved it. Optional for older files.
        var mapX: Double? = nil
        var mapY: Double? = nil
    }

    struct ReminderRecord: Codable {
        var text: String
        var createdAt: Date
    }

    struct ResetThoughtRecord: Codable {
        var text: String
        var perspective: String
        var sortOrder: Int
        var loop: String?
    }

    struct ParkedRecord: Codable {
        var text: String
        var createdAt: Date
        var reviewedAt: Date?
        var urgencyAtReview: Double
        var reviewNote: String
    }

    struct TinyStepRecord: Codable {
        var text: String
        var createdAt: Date
        var outcome: String?
        var snoozedUntil: Date?
    }

    struct CareerRecord: Codable {
        var createdAt: Date
        var moment: CareerMoment
        var topic: String
        var learned: String
        var interesting: String
        var enjoyment: Double
        var discouragement: Double
        var urgeToQuit: Double
        var quitSource: Double
    }

    // MARK: - Export

    /// Everything, as plain records. Throws if any part can't be read, so a backup
    /// is never quietly missing something: better no file than an incomplete one.
    static func snapshot(from context: ModelContext) throws -> Snapshot {
        func all<T: PersistentModel>(_ type: T.Type) throws -> [T] {
            try context.fetch(FetchDescriptor<T>())
        }
        var s = Snapshot()
        s.loops = try all(Loop.self).map {
            LoopRecord(name: $0.name, coreBelief: $0.coreBelief, pattern: $0.pattern, sortOrder: $0.sortOrder)
        }
        s.entries = try all(Entry.self).map { e in
            EntryRecord(createdAt: e.createdAt, kind: e.kind, text: e.text, drawingData: e.drawingData,
                        drawingBackground: e.drawingBackground, loop: e.loop?.name, isGood: e.isGood,
                        lightness: e.lightness,
                        compassionHard: e.compassionHard, compassionShared: e.compassionShared,
                        compassionNeed: e.compassionNeed,
                        reframe: e.reframe.map { r in
                            ReframeRecord(trigger: r.trigger, coreBelief: r.coreBelief, evidenceFor: r.evidenceFor,
                                          evidenceAgainst: r.evidenceAgainst, kinderRead: r.kinderRead,
                                          smallStep: r.smallStep, createdAt: r.createdAt,
                                          distressBefore: r.distressBefore, distressAfter: r.distressAfter,
                                          beliefBefore: r.beliefBefore, beliefAfter: r.beliefAfter,
                                          headTrue: r.headTrue >= 0 ? r.headTrue : nil,
                                          headLight: r.headLight >= 0 ? r.headLight : nil,
                                          laterHead: r.hasLater ? r.laterHead : nil,
                                          laterHeart: r.hasLater ? r.laterHeart : nil,
                                          laterAt: r.laterAt)
                        })
        }
        s.wins = try all(Win.self).map {
            WinRecord(createdAt: $0.createdAt, text: $0.text, meaning: $0.meaning, effortToOutcome: $0.effortToOutcome,
                      isPinned: $0.isPinned)
        }
        s.values = try all(PersonalValue.self).map {
            ValueRecord(name: $0.name, meaning: $0.meaning, livedLately: $0.livedLately, createdAt: $0.createdAt,
                        mapX: $0.mapX, mapY: $0.mapY)
        }
        s.reminders = try all(SavedReminder.self).map { ReminderRecord(text: $0.text, createdAt: $0.createdAt) }
        s.resetThoughts = try all(ResetThought.self).map {
            ResetThoughtRecord(text: $0.text, perspective: $0.perspective, sortOrder: $0.sortOrder, loop: $0.loop?.name)
        }
        s.parkedThoughts = try all(ParkedThought.self).map {
            ParkedRecord(text: $0.text, createdAt: $0.createdAt, reviewedAt: $0.reviewedAt,
                         urgencyAtReview: $0.urgencyAtReview, reviewNote: $0.reviewNote)
        }
        s.tinySteps = try all(TinyStep.self).map {
            TinyStepRecord(text: $0.text, createdAt: $0.createdAt, outcome: $0.outcome, snoozedUntil: $0.snoozedUntil)
        }
        s.careerReflections = try all(CareerReflection.self).map {
            CareerRecord(createdAt: $0.createdAt, moment: $0.moment, topic: $0.topic, learned: $0.learned,
                         interesting: $0.interesting, enjoyment: $0.enjoyment, discouragement: $0.discouragement,
                         urgeToQuit: $0.urgeToQuit, quitSource: $0.quitSource)
        }
        s.mapLinks = try all(MapLink.self).map {
            MapLinkRecord(loopA: $0.loopA?.name, loopB: $0.loopB?.name, value: $0.value?.name,
                          strength: $0.strength, status: $0.status, createdAt: $0.createdAt)
        }
        s.photos = try all(GroundingPhoto.self).map {
            PhotoRecord(imageData: $0.imageData, isCutout: $0.isCutout, caption: $0.caption, createdAt: $0.createdAt)
        }
        s.paths = try all(StepPath.self).map { path in
            PathRecord(title: path.title, createdAt: path.createdAt, isResting: path.isResting,
                       steps: path.everything.map {
                           StepRecord(text: $0.text, createdAt: $0.createdAt,
                                      isTide: $0.isTide ? true : nil,
                                      heaviness: $0.isTide ? $0.heaviness : nil,
                                      learned: $0.learned.isEmpty ? nil : $0.learned,
                                      shell: $0.shell.isEmpty ? nil : $0.shell)
                       },
                       nextStep: path.nextStep.isEmpty ? nil : path.nextStep,
                       nextSetAt: path.nextSetAt)
        }
        s.laughs = try all(Laugh.self).map { LaughRecord(text: $0.text, imageData: $0.imageData, createdAt: $0.createdAt) }
        return s
    }

    static func encode(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: data)
    }

    // MARK: - Restore

    /// How much was added, for a short message afterwards.
    struct RestoreSummary: Equatable {
        var added = 0
        var skipped = 0
    }

    /// Adds everything in the snapshot that isn't already here. Never deletes.
    /// All or nothing: if reading what's here or saving fails, everything this restore
    /// added is rolled back and the error is passed on, so it never reports records it didn't keep.
    @discardableResult
    static func restore(_ s: Snapshot, into context: ModelContext) throws -> RestoreSummary {
        do {
            let summary = try insertAll(s, into: context)
            try context.save()
            return summary
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func insertAll(_ s: Snapshot, into context: ModelContext) throws -> RestoreSummary {
        func all<T: PersistentModel>(_ type: T.Type) throws -> [T] {
            try context.fetch(FetchDescriptor<T>())
        }
        /// Dates are compared to the second, since JSON keeps whole seconds.
        func key(_ date: Date, _ text: String) -> String { "\(Int(date.timeIntervalSince1970))|\(text)" }

        var summary = RestoreSummary()

        // Loops first, so entries and reset thoughts can link to them by name.
        var loopsByName: [String: Loop] = [:]
        for loop in try all(Loop.self) { loopsByName[loop.name.lowercased()] = loop }
        for record in s.loops.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if loopsByName[record.name.lowercased()] != nil { summary.skipped += 1; continue }
            let order = (loopsByName.values.map(\.sortOrder).max() ?? -1) + 1
            let loop = Loop(name: record.name, coreBelief: record.coreBelief, pattern: record.pattern, sortOrder: order)
            context.insert(loop)
            loopsByName[record.name.lowercased()] = loop
            summary.added += 1
        }
        func loop(named name: String?) -> Loop? { name.flatMap { loopsByName[$0.lowercased()] } }

        let entryKeys = try Set(all(Entry.self).map { key($0.createdAt, $0.text) })
        for r in s.entries {
            if entryKeys.contains(key(r.createdAt, r.text)) { summary.skipped += 1; continue }
            let entry = Entry(kind: r.kind, text: r.text, drawingData: r.drawingData, createdAt: r.createdAt)
            context.insert(entry)
            entry.loop = loop(named: r.loop)
            entry.drawingBackground = r.drawingBackground
            entry.isGood = r.isGood
            entry.lightness = r.lightness
            entry.compassionHard = r.compassionHard
            entry.compassionShared = r.compassionShared
            entry.compassionNeed = r.compassionNeed
            if let f = r.reframe {
                let reframe = Reframe(trigger: f.trigger, coreBelief: f.coreBelief, kinderRead: f.kinderRead,
                                      smallStep: f.smallStep, createdAt: f.createdAt)
                reframe.evidenceFor = f.evidenceFor
                reframe.evidenceAgainst = f.evidenceAgainst
                reframe.distressBefore = f.distressBefore
                reframe.distressAfter = f.distressAfter
                reframe.beliefBefore = f.beliefBefore
                reframe.beliefAfter = f.beliefAfter
                reframe.headTrue = f.headTrue ?? -1
                reframe.headLight = f.headLight ?? -1
                reframe.laterHead = f.laterHead ?? -1
                reframe.laterHeart = f.laterHeart ?? -1
                reframe.laterAt = f.laterAt
                context.insert(reframe)
                entry.reframe = reframe
            }
            summary.added += 1
        }

        let winKeys = try Set(all(Win.self).map { key($0.createdAt, $0.text) })
        for r in s.wins {
            if winKeys.contains(key(r.createdAt, r.text)) { summary.skipped += 1; continue }
            let win = Win(text: r.text, meaning: r.meaning, effortToOutcome: r.effortToOutcome, createdAt: r.createdAt)
            win.isPinned = r.isPinned ?? false
            context.insert(win)
            summary.added += 1
        }

        var valuesByName: [String: PersonalValue] = [:]
        for value in try all(PersonalValue.self) { valuesByName[value.name.lowercased()] = value }
        for r in s.values {
            if valuesByName[r.name.lowercased()] != nil { summary.skipped += 1; continue }
            let value = PersonalValue(name: r.name, meaning: r.meaning, createdAt: r.createdAt)
            value.livedLately = r.livedLately
            value.mapX = r.mapX
            value.mapY = r.mapY
            context.insert(value)
            valuesByName[r.name.lowercased()] = value
            summary.added += 1
        }

        let reminderTexts = try Set(all(SavedReminder.self).map(\.text))
        for r in s.reminders {
            if reminderTexts.contains(r.text) { summary.skipped += 1; continue }
            context.insert(SavedReminder(text: r.text, createdAt: r.createdAt))
            summary.added += 1
        }

        let thoughtTexts = try Set(all(ResetThought.self).map(\.text))
        for r in s.resetThoughts {
            if thoughtTexts.contains(r.text) { summary.skipped += 1; continue }
            let thought = ResetThought(text: r.text, perspective: r.perspective, sortOrder: r.sortOrder)
            context.insert(thought)
            thought.loop = loop(named: r.loop)
            summary.added += 1
        }

        let parkedKeys = try Set(all(ParkedThought.self).map { key($0.createdAt, $0.text) })
        for r in s.parkedThoughts {
            if parkedKeys.contains(key(r.createdAt, r.text)) { summary.skipped += 1; continue }
            let parked = ParkedThought(text: r.text, createdAt: r.createdAt)
            parked.reviewedAt = r.reviewedAt
            parked.urgencyAtReview = r.urgencyAtReview
            parked.reviewNote = r.reviewNote
            context.insert(parked)
            summary.added += 1
        }

        let stepKeys = try Set(all(TinyStep.self).map { key($0.createdAt, $0.text) })
        for r in s.tinySteps {
            if stepKeys.contains(key(r.createdAt, r.text)) { summary.skipped += 1; continue }
            let step = TinyStep(text: r.text, createdAt: r.createdAt)
            step.outcome = r.outcome
            step.snoozedUntil = r.snoozedUntil
            context.insert(step)
            summary.added += 1
        }

        let careerKeys = try Set(all(CareerReflection.self).map { key($0.createdAt, $0.topic) })
        for r in s.careerReflections {
            if careerKeys.contains(key(r.createdAt, r.topic)) { summary.skipped += 1; continue }
            let c = CareerReflection(moment: r.moment, topic: r.topic, createdAt: r.createdAt)
            c.learned = r.learned
            c.interesting = r.interesting
            c.enjoyment = r.enjoyment
            c.discouragement = r.discouragement
            c.urgeToQuit = r.urgeToQuit
            c.quitSource = r.quitSource
            context.insert(c)
            summary.added += 1
        }

        let photoKeys = try Set(all(GroundingPhoto.self).map { key($0.createdAt, $0.caption) })
        for r in s.photos ?? [] {
            if photoKeys.contains(key(r.createdAt, r.caption)) { summary.skipped += 1; continue }
            context.insert(GroundingPhoto(imageData: r.imageData, isCutout: r.isCutout, caption: r.caption, createdAt: r.createdAt))
            summary.added += 1
        }

        // Paths are matched by name and start date; their steps are merged in.
        var pathsByKey = try Dictionary(all(StepPath.self).map { (key($0.createdAt, $0.title), $0) }, uniquingKeysWith: { a, _ in a })
        for r in s.paths ?? [] {
            let path: StepPath
            if let existing = pathsByKey[key(r.createdAt, r.title)] {
                path = existing
                summary.skipped += 1
            } else {
                path = StepPath(title: r.title, createdAt: r.createdAt)
                context.insert(path)
                path.isResting = r.isResting
                path.nextStep = r.nextStep ?? ""
                path.nextSetAt = r.nextSetAt
                pathsByKey[key(r.createdAt, r.title)] = path
                summary.added += 1
            }
            let stepKeys = Set(path.steps.map { key($0.createdAt, $0.text) })
            for step in r.steps where !stepKeys.contains(key(step.createdAt, step.text)) {
                let footstep = Footstep(text: step.text, createdAt: step.createdAt)
                footstep.isTide = step.isTide ?? false
                footstep.heaviness = step.heaviness ?? 0
                footstep.learned = step.learned ?? ""
                footstep.shell = step.shell ?? ""
                context.insert(footstep)
                footstep.path = path
            }
        }

        let laughKeys = try Set(all(Laugh.self).map { key($0.createdAt, $0.text) })
        for r in s.laughs ?? [] {
            if laughKeys.contains(key(r.createdAt, r.text)) { summary.skipped += 1; continue }
            context.insert(Laugh(text: r.text, imageData: r.imageData, createdAt: r.createdAt))
            summary.added += 1
        }

        // Map links last, once every loop and value they point at exists.
        // A link is the same if it joins the same two things, in either order.
        func linkKey(_ a: String?, _ b: String?, _ v: String?) -> String {
            let loops = [a, b].compactMap { $0?.lowercased() }.sorted()
            return loops.joined(separator: "|") + "|" + (v?.lowercased() ?? "")
        }
        var linkKeys = try Set(all(MapLink.self).map { linkKey($0.loopA?.name, $0.loopB?.name, $0.value?.name) })
        for r in s.mapLinks ?? [] {
            let key = linkKey(r.loopA, r.loopB, r.value)
            let loopA = loop(named: r.loopA)
            let loopB = loop(named: r.loopB)
            let value = r.value.flatMap { valuesByName[$0.lowercased()] }
            // Skip duplicates, and links whose loops or value are missing from the file.
            guard !linkKeys.contains(key), loopA != nil, (loopB != nil) != (value != nil) else {
                summary.skipped += 1; continue
            }
            let link = MapLink()
            context.insert(link)
            link.loopA = loopA
            link.loopB = loopB
            link.value = value
            link.strength = r.strength
            link.status = r.status
            link.createdAt = r.createdAt
            linkKeys.insert(key)
            summary.added += 1
        }

        return summary
    }
}
