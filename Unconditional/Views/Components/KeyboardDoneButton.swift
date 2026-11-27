import SwiftUI
import UIKit

/// Adds a "Done" button above the keyboard that hides it.
///
/// A multi-line `TextEditor` uses Return for new lines, so without this
/// there's no obvious way to put the keyboard away.
struct KeyboardDoneButton: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { Keyboard.hide() }
            }
        }
    }
}

extension View {
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneButton()) }
}

enum Keyboard {
    /// Asks whichever text field is active to give up focus, which hides the keyboard.
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
