import SwiftUI
import UIKit

/// The three color themes. The choice is saved with `@AppStorage("theme")`,
/// which writes to UserDefaults, so it survives app restarts.
enum Theme: String, CaseIterable, Identifiable {
    case sage, dusk, sky

    static let storageKey = "theme"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sage: "Sage"
        case .dusk: "Dusk"
        case .sky: "Sky"
        }
    }

    var mood: String {
        switch self {
        case .sage: "Grounded, like a paper journal"
        case .dusk: "Soft and soothing, for evenings"
        case .sky: "Open and light"
        }
    }

    /// Buttons, toggles, chart bars, and links use this color.
    var accent: Color {
        switch self {
        case .sage: Color(light: 0x5F8466, dark: 0x93B496)
        case .dusk: Color(light: 0x8A6FB0, dark: 0xB9A2DB)
        case .sky: Color(light: 0x3F7FAE, dark: 0x7FB3DA)
        }
    }

    /// Two background colors. Sage and Sky are nearly flat; Dusk is a real gradient.
    var backgroundColors: [Color] {
        switch self {
        case .sage: [Color(light: 0xF6F1E6, dark: 0x1B1E1A), Color(light: 0xEEF0E4, dark: 0x1F231E)]
        case .dusk: [Color(light: 0xE9E2F6, dark: 0x221D30), Color(light: 0xFAE4D8, dark: 0x30222A)]
        case .sky: [Color(light: 0xEAF3FB, dark: 0x131B24), Color(light: 0xF7FAFD, dark: 0x18222D)]
        }
    }

    var background: LinearGradient {
        LinearGradient(colors: backgroundColors, startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    /// A color that switches automatically between light and dark mode.
    /// Hex values like 0x5F8466 are the same as "#5F8466" in design tools.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// The current theme's background, filling the whole screen.
struct ThemeBackground: View {
    @AppStorage(Theme.storageKey) private var theme: Theme = .sage

    var body: some View {
        theme.background.ignoresSafeArea()
    }
}

/// Replaces the default grey List/Form background with the theme's background.
struct ThemedBackground: ViewModifier {
    @AppStorage(Theme.storageKey) private var theme: Theme = .sage

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
    }
}

extension View {
    func themedBackground() -> some View { modifier(ThemedBackground()) }
}
