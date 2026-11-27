import Foundation
import SwiftData

/// How an entry was made. Stored as its raw `String`.
/// Speak entries are stored as text, transcribed from your voice.
enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case write
    case speak
    case draw
    /// One word at a time: lean each toward heavier or lighter, and related words bubble up.
    case words

    var id: String { rawValue }

    var label: String {
        switch self {
        case .write: "Write"
        case .speak: "Speak"
        case .draw: "Draw"
        case .words: "Words"
        }
    }

    var symbol: String {
        switch self {
        case .write: "pencil.line"
        case .speak: "mic"
        case .draw: "scribble.variable"
        case .words: "bubble.left.and.bubble.right"
        }
    }

    /// Write, Speak and Words all produce text.
    var isText: Bool { self != .draw }
}

/// One day's (or moment's) journal entry.
@Model
final class Entry {
    var createdAt: Date
    var kind: EntryKind
    var text: String

    /// A PencilKit drawing saved as `Data` (`PKDrawing.dataRepresentation()`).
    /// `.externalStorage` lets SwiftData keep large blobs in a separate file
    /// instead of inside the database row.
    @Attribute(.externalStorage)
    var drawingData: Data?

    /// Which paper the drawing was made on (a `CanvasBackground` raw value).
    var drawingBackground: String = "paper"

    /// Which loop this thought belongs to. Optional: you might not know yet.
    var loop: Loop?

    /// A good moment rather than a hard one. Set from `lightness` when you save
    /// (0.6 or lighter), so older parts of the app that ask "was it good?" still work.
    var isGood: Bool = false

    /// "How does this sit?" after a check-in: 0 is heavy, 1 is light.
    /// Optional: nil means you skipped the slider.
    var lightness: Double?

    /// Light enough to count as a good moment.
    static let lightThreshold = 0.6

    // Self-compassion break: three short reflections, all optional.
    /// "This is hard." Naming the difficulty.
    var compassionHard: String = ""
    /// "Others feel this too." Common humanity.
    var compassionShared: String = ""
    /// "What do I need right now?" Kindness toward yourself.
    var compassionNeed: String = ""

    var hasCompassion: Bool {
        !(compassionHard + compassionShared + compassionNeed).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The optional CBT reframe. `.cascade` means deleting an entry deletes its reframe too.
    @Relationship(deleteRule: .cascade, inverse: \Reframe.entry)
    var reframe: Reframe?

    init(kind: EntryKind, text: String = "", drawingData: Data? = nil, loop: Loop? = nil, createdAt: Date = .now) {
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
        self.drawingData = drawingData
        self.loop = loop
    }
}
