import SwiftUI
import UIKit

/// The "paper journal" look: serif headings, roomy spacing, and soft cards
/// that float on the background with a gentle shadow instead of hard borders.
enum Paper {
    /// Warm off-white cards in light mode, a slightly lifted surface in dark mode.
    static let card = Color(uiColor: cardUIColor)
    static let cardUIColor = UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? 0x262626 : 0xFFFDF9)
    }
    static let cornerRadius: CGFloat = 22

    /// Makes every navigation title (e.g. "History") use Apple's serif font, New York.
    /// SwiftUI has no direct API for this yet, so we set the UIKit appearance once at launch.
    static func applySerifNavigationTitles() {
        func serif(_ style: UIFont.TextStyle) -> UIFont {
            let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            let descriptor = (base.withDesign(.serif) ?? base).withSymbolicTraits(.traitBold) ?? base
            return UIFont(descriptor: descriptor, size: 0)
        }
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: serif(.largeTitle)]
        appearance.titleTextAttributes = [.font: serif(.headline)]
    }
}

/// Wraps content in a soft card.
struct PaperCard: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paper.card, in: RoundedRectangle(cornerRadius: Paper.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }
}

extension View {
    func paperCard(padding: CGFloat = 20) -> some View { modifier(PaperCard(padding: padding)) }

    /// Softer List/Form rows: paper-colored, extra space between sections.
    func paperList() -> some View {
        self
            .listSectionSpacing(28)
            .environment(\.defaultMinListRowHeight, 52)
    }
}

/// A large serif heading with an optional softer line under it.
struct PaperHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title, design: .serif).weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The main action button: full width, tinted, softly rounded.
struct PaperButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PaperButtonStyle {
    static var paper: PaperButtonStyle { PaperButtonStyle() }
}
