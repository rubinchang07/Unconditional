import Foundation
import SwiftData

/// A small success, logged on purpose to counter the habit of discounting them.
@Model
final class Win {
    var createdAt: Date
    var text: String
    /// Optional: what this win says about you, e.g. "I keep showing up even when it's hard."
    var meaning: String

    init(text: String, meaning: String = "", createdAt: Date = .now) {
        self.createdAt = createdAt
        self.text = text
        self.meaning = meaning
    }
}
