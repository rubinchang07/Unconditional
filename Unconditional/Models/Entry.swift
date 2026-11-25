import Foundation
import SwiftData

/// Whether an entry was written or drawn. Stored as its raw `String`.
enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case write
    case draw

    var id: String { rawValue }
    var label: String { self == .write ? "Write" : "Draw" }
    var symbol: String { self == .write ? "pencil.line" : "scribble.variable" }
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

    /// Which loop this thought belongs to. Optional: you might not know yet.
    var loop: Loop?

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
