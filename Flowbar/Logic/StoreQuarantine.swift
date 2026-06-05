import Foundation

/// Açılamayan (migrate edilemeyen/bozuk) SwiftData store'unu **silmek yerine**
/// kenara taşır. Böylece açılış hatasında kullanıcı verisi yok edilmez,
/// `.corrupt-<zaman>` ekiyle saklanır ve sonradan kurtarılabilir.
enum StoreQuarantine {
    /// Verilen store dosyasını ve yan dosyalarını (-wal, -shm) karantinaya alır.
    /// Silmez; her birini `<ad>.corrupt-<zaman><suffix>` olarak yeniden adlandırır.
    static func quarantine(storeAt storeURL: URL) {
        let fm = FileManager.default
        let stamp = Self.timestamp()
        for suffix in ["", "-wal", "-shm"] {
            let url = sibling(storeURL, suffix)
            guard fm.fileExists(atPath: url.path) else { continue }
            let dest = storeURL.deletingLastPathComponent()
                .appendingPathComponent("\(storeURL.lastPathComponent).corrupt-\(stamp)\(suffix)")
            try? fm.moveItem(at: url, to: dest)
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private static func sibling(_ storeURL: URL, _ suffix: String) -> URL {
        storeURL.deletingLastPathComponent()
            .appendingPathComponent(storeURL.lastPathComponent + suffix)
    }
}
