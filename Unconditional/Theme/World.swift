import SwiftUI

/// What ties every scene back to the orb: one rhythm, one set of colors, one soft light.
///
/// Water, sand, leaves, waves and stones all take their color from the orb palette you
/// chose, everything that bobs, sways or ripples moves at the orb's breath, and anything
/// that's yours (a kept word, a shell, a leaf) carries the orb's soft inner glow.
enum Rhythm {
    /// One slow breath, the same as the orb's: four seconds in, six out.
    static let breath = 10.0

    /// A gentle -1...1 sway at the breath's tempo. `beats` is how many sways per breath
    /// (half, one, two...), so things can move slower or faster but stay in time.
    static func sway(_ t: Double, beats: Double = 1, phase: Double = 0) -> Double {
        sin(2 * .pi * t * beats / breath + phase)
    }
}

/// The colors of the world around the orb, made from its palette.
struct WorldColors {
    /// Water: the stream, the tide, the waves. The palette's outer glow, cooled a little.
    let water: Color
    /// Water at rest, paler.
    let stillWater: Color
    /// The orb's inner light, for glows and highlights.
    let light: Color
    /// The orb's body color, for warmth.
    let body: Color
}

extension OrbPalette {
    var world: WorldColors {
        let c = colors
        let water = c[0].mix(with: Color(hex: 0x8FBFCB), by: 0.4)
        return WorldColors(water: water, stillWater: water.mix(with: .white, by: 0.55), light: c[2], body: c[1])
    }
}

extension View {
    /// The orb's soft inner light, on something that's yours.
    func ownGlow(_ color: Color, radius: CGFloat = 7) -> some View {
        shadow(color: color.opacity(0.55), radius: radius)
    }
}
