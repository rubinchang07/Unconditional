import Foundation
import UserNotifications

/// Schedules (or cancels) one gentle daily notification.
enum ReminderScheduler {
    static let enabledKey = "reminderEnabled"
    /// Minutes after midnight, e.g. 21 * 60 = 9:00 PM.
    static let timeKey = "reminderMinutes"
    static let defaultMinutes = 21 * 60

    private static let id = "daily-reminder"

    /// Returns false if the user declined notifications.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "A few minutes for you"
        content.body = "Write, draw, or say what's on your mind. Or just log one small win."
        content.sound = .default

        var time = DateComponents()
        time.hour = minutes / 60
        time.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
