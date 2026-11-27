import Foundation
import SwiftData

/// A connection that *you* confirmed or turned down, from the map that used to be in
/// Insights. The map was removed (it asked too much for too little), but links are
/// kept so existing data and backups still open and round-trip.
///
/// The app only ever suggests links. A link exists because you said it feels
/// connected, and `strength` says how much (a spectrum, not yes or no).
/// Either two loops (`loopA` and `loopB`) or a loop and a value (`loopA` and `value`).
@Model
final class MapLink {
    var loopA: Loop?
    var loopB: Loop?
    var value: PersonalValue?
    /// How connected it feels, 0 to 1.
    var strength: Double = 0.5
    /// "confirmed", or "dismissed" so the same suggestion doesn't come back.
    var status: String = "confirmed"
    var createdAt: Date = Date.now

    init() {}

    var isConfirmed: Bool { status == "confirmed" }

    /// True when this link joins exactly these two loops, in either order.
    func joins(_ a: Loop, _ b: Loop) -> Bool {
        (loopA == a && loopB == b) || (loopA == b && loopB == a)
    }
}

extension Loop {
    /// Soft colors for loops by order, shared by Patterns and the map.
    static let palette: [UInt32] = [0xE9785E, 0x9B86C4, 0x6FA3CC, 0xE8B07E, 0x7FA383]
}

extension MapLink {
    /// How strong a link is, in words, never a number.
    static func strengthLabel(_ value: Double) -> String {
        switch value {
        case ..<0.05: "not linked"
        case ..<0.35: "a little"
        case ..<0.7: "somewhat"
        default: "strongly"
        }
    }
}
