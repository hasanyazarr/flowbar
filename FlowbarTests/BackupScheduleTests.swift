import XCTest
@testable import Flowbar

/// Otomatik yedekleme zamanlama + rotasyon mantığının saf testleri (I/O'suz).
final class BackupScheduleTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: - shouldBackup (günde 1: aynı takvim gününde tekrar yedeklenmez)

    func test_daily_backsUpWhenNeverBackedUp() {
        XCTAssertTrue(BackupSchedule.shouldBackup(
            frequency: "daily", lastBackup: nil, now: date(2026, 6, 5), calendar: cal))
    }

    func test_daily_skipsWhenAlreadyBackedUpToday() {
        XCTAssertFalse(BackupSchedule.shouldBackup(
            frequency: "daily", lastBackup: date(2026, 6, 5, 9), now: date(2026, 6, 5, 21), calendar: cal))
    }

    func test_daily_backsUpOnNewDay() {
        XCTAssertTrue(BackupSchedule.shouldBackup(
            frequency: "daily", lastBackup: date(2026, 6, 4, 23), now: date(2026, 6, 5, 1), calendar: cal))
    }

    func test_off_neverBacksUp() {
        XCTAssertFalse(BackupSchedule.shouldBackup(
            frequency: "never", lastBackup: nil, now: date(2026, 6, 5), calendar: cal))
    }

    func test_weekly_waitsSevenDays() {
        XCTAssertFalse(BackupSchedule.shouldBackup(
            frequency: "weekly", lastBackup: date(2026, 6, 1), now: date(2026, 6, 5), calendar: cal))
        XCTAssertTrue(BackupSchedule.shouldBackup(
            frequency: "weekly", lastBackup: date(2026, 6, 1), now: date(2026, 6, 9), calendar: cal))
    }

    // MARK: - rotation (en yeni N tutulur, kalanı silinmek üzere döndürülür)

    func test_rotation_keepsNewestAndReturnsRest() {
        let files = [
            "flowbar_backup_2026-06-01.store",
            "flowbar_backup_2026-06-02.store",
            "flowbar_backup_2026-06-03.store",
            "flowbar_backup_2026-06-04.store",
        ]
        let toDelete = BackupSchedule.expiredBackups(files, keeping: 2)
        XCTAssertEqual(toDelete.sorted(), [
            "flowbar_backup_2026-06-01.store",
            "flowbar_backup_2026-06-02.store",
        ])
    }

    func test_rotation_nothingToDeleteUnderLimit() {
        let files = ["flowbar_backup_2026-06-01.store", "flowbar_backup_2026-06-02.store"]
        XCTAssertTrue(BackupSchedule.expiredBackups(files, keeping: 7).isEmpty)
    }

    func test_rotation_ignoresUnrelatedFiles() {
        let files = ["notes.txt", "flowbar_backup_2026-06-01.store"]
        XCTAssertTrue(BackupSchedule.expiredBackups(files, keeping: 0).contains("flowbar_backup_2026-06-01.store"))
        XCTAssertFalse(BackupSchedule.expiredBackups(files, keeping: 0).contains("notes.txt"))
    }
}
