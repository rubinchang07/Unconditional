import SwiftUI

/// A wordless "press and hold here": a small hand pressing down while a ring
/// slowly spreads out from under it. Shown once for a hidden gesture, until
/// you've used that gesture.
struct HoldCue: View {
    var color: Color = .secondary
    var size: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(pressing ? 0 : 0.5), lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(pressing ? 1.5 : 0.6)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: size * 0.5))
                .foregroundStyle(color)
                .scaleEffect(pressing ? 0.86 : 1)
                .offset(x: size * 0.12, y: size * 0.18)
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { pressing = true }
        }
        .accessibilityHidden(true)
    }
}
