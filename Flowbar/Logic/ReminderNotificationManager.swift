import Foundation
import UserNotifications

@MainActor
enum ReminderNotificationManager {
    /// macOS bildirim izni ister.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Bir hatırlatıcı için yerel macOS bildirimi planlar.
    static func scheduleNotification(for reminder: Reminder) {
        guard let remindAt = reminder.remindAt, remindAt > Date() else { return }

        let content = UNMutableNotificationContent()
        if let project = reminder.project {
            content.title = "Hatırlatıcı: \(project.name)"
        } else {
            content.title = "Hatırlatıcı"
        }
        content.body = reminder.content
        content.sound = .default

        let timeInterval = remindAt.timeIntervalSinceNow
        // Zamanlayıcı tetikleyicisi (TimeIntervalTrigger) en az 1 saniye olmalı.
        let safeInterval = max(1.0, timeInterval)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: safeInterval, repeats: false)

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// Bekleyen bildirimi iptal eder.
    static func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }
}
