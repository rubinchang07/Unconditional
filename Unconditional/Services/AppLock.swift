import Foundation
import LocalAuthentication

/// Face ID (or passcode) check, using the LocalAuthentication framework.
enum AppLock {
    static let enabledKey = "lockEnabled"

    /// `.deviceOwnerAuthentication` tries Face ID first and falls back to the
    /// phone's passcode, so you can never lock yourself out.
    static func authenticate(reason: String = "Unlock your journal") async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
