import SwiftUI

/// A grounding photo as an iPhone-style sticker: a white die-cut border around
/// the subject, a soft lift off the page, and a gentle light that travels
/// slowly around the edge, like a highlight catching the sticker's gloss.
struct StickerView: View {
    let image: UIImage
    let isCutout: Bool
    var glow: Color = .white
    /// Border width in points.
    var border: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            // One slow lap every 6 seconds.
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6)
            let angle = Angle.degrees(reduceMotion ? 200 : t / 6 * 360)
            Group {
                if isCutout { cutout(angle) } else { framed(angle) }
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 5)
    }

    /// The light: mostly clear, with one bright streak and a fading tail behind it.
    private func trail(_ angle: Angle) -> AngularGradient {
        AngularGradient(stops: [
            .init(color: glow.opacity(0), location: 0),
            .init(color: glow.opacity(0), location: 0.62),
            .init(color: glow.opacity(0.55), location: 0.86),
            .init(color: glow, location: 0.97),
            .init(color: glow.opacity(0), location: 1),
        ], center: .center, angle: angle)
    }

    // MARK: - Lifted subject

    private var silhouette: some View {
        Image(uiImage: image)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
    }

    /// The subject's shape grown outward by `border`, by drawing it 16 times in a circle.
    private var outline: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let a = Double(index) / 16 * 2 * .pi
                silhouette.offset(x: cos(a) * border, y: sin(a) * border)
            }
        }
    }

    private func cutout(_ angle: Angle) -> some View {
        ZStack {
            outline.foregroundStyle(.white)
            // The light only shows on the white edge: it's clipped to the outline,
            // and the photo sits on top of everything inside it.
            Rectangle()
                .fill(trail(angle))
                .blur(radius: 2)
                .mask(outline)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        .padding(border)
    }

    // MARK: - Whole photo

    private func framed(_ angle: Angle) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 18 - border, style: .continuous))
            .padding(border)
            .background(.white, in: shape)
            .overlay {
                shape
                    .strokeBorder(trail(angle), lineWidth: border)
                    .blur(radius: 1)
            }
    }
}
