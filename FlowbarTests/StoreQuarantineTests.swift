import XCTest
@testable import Flowbar

/// Açılamayan (migrate edilemeyen/bozuk) store'un ASLA silinmemesi gerektiğini
/// doğrular. Eskiden PersistenceController hata anında store dosyalarını siliyordu;
/// bu, lightweight migration başarısız olduğunda kullanıcının tüm verisini yok etti.
/// Artık dosyalar `.corrupt-<zaman>` ekiyle kenara taşınır, böylece kurtarılabilir.
final class StoreQuarantineTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("flowbar-quarantine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_quarantine_movesStoreFilesInsteadOfDeleting() throws {
        let fm = FileManager.default
        let storeURL = tempDir.appendingPathComponent("default.store")
        let walURL = tempDir.appendingPathComponent("default.store-wal")
        try "real-user-data".write(to: storeURL, atomically: true, encoding: .utf8)
        try "wal".write(to: walURL, atomically: true, encoding: .utf8)

        StoreQuarantine.quarantine(storeAt: storeURL)

        // Orijinal isimler artık yok (taşındı), AMA veri hâlâ diskte bir yerde.
        XCTAssertFalse(fm.fileExists(atPath: storeURL.path), "Bozuk store orijinal adında kalmamalı")

        let moved = try fm.contentsOfDirectory(atPath: tempDir.path)
        let corruptCopies = moved.filter { $0.contains("default.store") && $0.contains("corrupt") }
        XCTAssertFalse(corruptCopies.isEmpty, "Bozuk store .corrupt- ekiyle korunmalı, silinmemeli")

        // İçerik korunmuş olmalı — kullanıcı verisi kurtarılabilir.
        let movedStore = tempDir.appendingPathComponent(corruptCopies.first { !$0.contains("wal") }!)
        let recovered = try String(contentsOf: movedStore, encoding: .utf8)
        XCTAssertEqual(recovered, "real-user-data")
    }
}
