import Foundation
import SwiftData

/// A small success, logged on purpose to counter the habit of discounting them.
@Model
final class Win {
    var createdAt: Date
    var text: String
    /// Optional: what this win says about you, e.g. "I keep showing up even when it's hard."
    var meaning: String
    /// Where this win sits between pure effort (0) and a result that worked out (1).
    /// A spectrum, because most wins are some of both, and effort counts.
    var effortToOutcome: Double = 0.5

    init(text: String, meaning: String = "", effortToOutcome: Double = 0.5, createdAt: Date = .now) {
        self.createdAt = createdAt
        self.text = text
        self.meaning = meaning
        self.effortToOutcome = effortToOutcome
    }

    /// A gentle label for the slider position.
    var effortLabel: String { Self.effortLabel(for: effortToOutcome) }

    static func effortLabel(for value: Double) -> String {
        switch value {
        case ..<0.2: "Effort"
        case ..<0.4: "Mostly effort"
        case ..<0.6: "Effort and outcome"
        case ..<0.8: "Mostly outcome"
        default: "Outcome"
        }
    }
}
