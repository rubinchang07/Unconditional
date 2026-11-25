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
    /// Kept at the surface of Anchors however old it gets.
    var isPinned: Bool = false

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

    // MARK: - Surface and settled

    /// Wins stay at the surface of Anchors for about two weeks, then settle
    /// into "kept over time". Nothing is ever deleted on its own.
    static let surfaceDays = 14

    /// Recent and pinned wins (pinned first), and the older ones that have settled.
    static func split(_ wins: [Win], now: Date = .now) -> (surface: [Win], settled: [Win]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -surfaceDays, to: now) ?? now
        let surface = wins.filter { $0.isPinned || $0.createdAt >= cutoff }
            .sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
        let settled = wins.filter { !$0.isPinned && $0.createdAt < cutoff }
            .sorted { $0.createdAt > $1.createdAt }
        return (surface, settled)
    }
}
