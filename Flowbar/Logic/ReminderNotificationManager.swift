import Foundation
import UserNotifications
import SwiftData

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
            content.title = String(localized: "Reminder: \(project.name)")
        } else {
            content.title = String(localized: "Reminder")
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
    
    /// Otomatik yedekleme başarılı bildirimi gönderir.
    static func sendBackupNotification(fileName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Automatic Backup Successful")
        content.body = String(localized: "\(fileName) was saved to your backup folder.")
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "auto_backup_notification",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

// MARK: - Auto Backup Manager
final class AutoBackupManager: ObservableObject {
    static let shared = AutoBackupManager()
    
    private init() {}
    
    // Bookmark kaydeder
    func saveBookmark(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "backupDirectoryBookmark")
            UserDefaults.standard.set(url.path, forKey: "backupDirectoryPath")
        } catch {
            print("AutoBackupManager: Failed to create bookmark: \(error)")
        }
    }
    
    // Bookmark çözümler
    func restoreBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "backupDirectoryBookmark") else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                saveBookmark(url: url)
            }
            return url
        } catch {
            print("AutoBackupManager: Failed to resolve bookmark: \(error)")
            return nil
        }
    }
    
    // Otomatik yedekleme koşullarını kontrol eder ve çalıştırır
    func checkAndRunBackup(sessions: [Session]) {
        let frequency = UserDefaults.standard.string(forKey: "backupFrequency") ?? "never"
        guard frequency != "never" else { return }
        
        guard let backupURL = restoreBookmark() else { return }
        
        let lastBackupTime = UserDefaults.standard.double(forKey: "lastBackupDate")
        let lastBackupDate = Date(timeIntervalSince1970: lastBackupTime)
        
        let interval: TimeInterval
        if frequency == "weekly" {
            interval = 7 * 24 * 60 * 60 // 7 gün
        } else if frequency == "monthly" {
            interval = 30 * 24 * 60 * 60 // 30 gün
        } else {
            return
        }
        
        let timePassed = Date().timeIntervalSince(lastBackupDate)
        if timePassed >= interval {
            triggerBackup(sessions: sessions, to: backupURL)
        }
    }
    
    // Asıl yedekleme işlemini yapar
    func triggerBackup(sessions: [Session], to url: URL) {
        struct SessionJSON: Codable {
            let id: String
            let project: String?
            let category: String?
            let note: String
            let startedAt: String
            let endedAt: String
            let measuredSeconds: Int
            let loggedSeconds: Int
        }
        
        let isoFormatter = ISO8601DateFormatter()
        let sortedSessions = sessions.sorted { $0.startedAt > $1.startedAt }
        
        let jsonSessions = sortedSessions.map { session in
            SessionJSON(
                id: session.id.uuidString,
                project: session.project?.name,
                category: session.project?.category?.name,
                note: session.note,
                startedAt: isoFormatter.string(from: session.startedAt),
                endedAt: isoFormatter.string(from: session.endedAt),
                measuredSeconds: session.measuredSeconds,
                loggedSeconds: session.loggedSeconds
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(jsonSessions)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateStr = dateFormatter.string(from: Date())
            let fileName = "flowbar_backup_\(dateStr).json"
            
            let fileURL = url.appendingPathComponent(fileName)
            
            // Güvenlik Kapsamlı URL erişimini başlat
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            try data.write(to: fileURL)
            
            // Tarih ve bildirimleri güncelle
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackupDate")
            
            DispatchQueue.main.async {
                ReminderNotificationManager.sendBackupNotification(fileName: fileName)
            }
            
            print("AutoBackupManager: Backup successfully saved to \(fileURL.path)")
            
        } catch {
            print("AutoBackupManager: Backup failed: \(error.localizedDescription)")
        }
    }
}
