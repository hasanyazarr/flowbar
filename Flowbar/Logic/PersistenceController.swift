import Foundation
import SwiftData

/// SwiftData ModelContainer'ı dayanıklı şekilde oluşturur.
/// Şema uyumsuzluğu (ör. migrate edilemeyen eski store) durumunda bozuk store
/// dosyalarını silip yeniden dener; yine olmazsa in-memory'ye düşer (app çökmez).
enum PersistenceController {
    static let models: [any PersistentModel.Type] = [Project.self, Session.self, Category.self, Reminder.self]

    static func makeContainer() -> ModelContainer {
        let schema = Schema(models)

        // 1. Normal (kalıcı) deneme.
        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // 2. Migrate edilemeyen eski store'u sil ve tekrar dene.
        deleteDefaultStore()
        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // 3. Son çare: in-memory (veri kalıcı olmaz ama app açılır).
        let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: inMemory)
        } catch {
            fatalError("In-memory ModelContainer bile oluşturulamadı: \(error)")
        }
    }

    /// Varsayılan SwiftData store dosyalarını (.store, -shm, -wal) siler.
    private static func deleteDefaultStore() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }

        for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
            let url = appSupport.appendingPathComponent(suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
