import Foundation
import SwiftData

/// What a career reflection is about.
enum CareerMoment: String, Codable, CaseIterable, Identifiable {
    case study, application, interview, setback

    var id: String { rawValue }

    var label: String {
        switch self {
        case .study: "Study session"
        case .application: "Application"
        case .interview: "Interview"
        case .setback: "Rejection or setback"
        }
    }

    var symbol: String {
        switch self {
        case .study: "book"
        case .application: "paperplane"
        case .interview: "person.2"
        case .setback: "cloud.drizzle"
        }
    }

    var topicPrompt: String {
        switch self {
        case .study: "What did you work on? e.g. Two-pointer problems"
        case .application: "Where did you apply?"
        case .interview: "Which interview?"
        case .setback: "What happened?"
        }
    }
}

/// A short reflection after studying or job searching.
///
/// The goal is to tell apart two very different feelings that can sound the same:
/// "I don't like this work" and "I don't like feeling incompetent at this work."
@Model
final class CareerReflection {
    var createdAt: Date
    var moment: CareerMoment
    var topic: String
    /// What you learned, even something small.
    var learned: String = ""
    /// What caught your interest or felt good to do.
    var interesting: String = ""

    // Sliders, 0 to 10. Feelings come in degrees.
    var enjoyment: Double = 5
    var discouragement: Double = 5
    var urgeToQuit: Double = 0
    /// If there's an urge to quit, where does it come from?
    /// 0 = "I don't like the work itself", 1 = "I'm discouraged / feel incompetent".
    var quitSource: Double = 0.5

    init(moment: CareerMoment, topic: String = "", createdAt: Date = .now) {
        self.moment = moment
        self.topic = topic
        self.createdAt = createdAt
    }

    /// The urge to quit only counts as "present" above a low threshold.
    var hasUrgeToQuit: Bool { urgeToQuit >= 3 }
}
