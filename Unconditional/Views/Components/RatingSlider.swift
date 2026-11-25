import SwiftUI

/// A labeled slider for "how much" questions. Feelings sit on a spectrum,
/// so we ask for a degree rather than a yes or no.
struct RatingSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...10
    var step: Double = 1
    var lowLabel: String
    var highLabel: String
    var valueText: (Double) -> String = { "\(Int($0))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText(value))
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText(value))
            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .animation(.easeOut(duration: 0.15), value: value)
    }
}
