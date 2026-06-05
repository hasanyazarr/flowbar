import Foundation

/// Otomatik yedekleme zamanlama ve rotasyon kararları (saf, I/O'suz — test edilebilir).
enum BackupSchedule {
    /// Verilen frekans, son yedek zamanı ve şimdiye göre yedek alınmalı mı?
    /// - daily: aynı takvim gününde tekrar alınmaz (günde 1)
    /// - weekly/monthly: son yedekten beri ilgili süre geçtiyse
    /// - never: asla
    static func shouldBackup(frequency: String, lastBackup: Date?, now: Date,
                             calendar: Calendar) -> Bool {
        guard frequency != "never" else { return false }
        guard let lastBackup else { return true }  // hiç yedek yoksa al

        switch frequency {
        case "daily":
            // Aynı takvim gününde tekrar alma.
            return !calendar.isDate(lastBackup, inSameDayAs: now)
        case "weekly":
            return now.timeIntervalSince(lastBackup) >= 7 * 24 * 60 * 60
        case "monthly":
            return now.timeIntervalSince(lastBackup) >= 30 * 24 * 60 * 60
        default:
            return false
        }
    }

    /// Yedek dosyası adlarından, en yeni `keeping` tanesini koruyup silinecekleri döndürür.
    /// Sadece `flowbar_backup_` ile başlayan dosyalar dikkate alınır. Dosya adları
    /// tarih içerdiği için sözlüksel sıralama = kronolojik sıralama.
    static func expiredBackups(_ fileNames: [String], keeping: Int) -> [String] {
        let backups = fileNames.filter { $0.hasPrefix("flowbar_backup_") }.sorted()
        guard backups.count > keeping else { return [] }
        return Array(backups.dropLast(keeping))
    }
}
