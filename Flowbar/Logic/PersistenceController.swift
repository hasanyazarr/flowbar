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

        // 2. Migrate edilemeyen store'u SİLME — kenara taşı (kurtarılabilir kalsın)
        //    ve tekrar dene. Eskiden burada veri siliniyordu; bu, lightweight
        //    migration başarısız olduğunda kullanıcının tüm verisini yok etti.
        quarantineDefaultStore()
        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // 3. Son çare: in-memory (veri kalıcı olmaz ama app açılır).
        let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: inMemory)
        } catch {
            fatalError("Could not even create an in-memory ModelContainer: \(error)")
        }
    }

    /// Varsayılan SwiftData store'unu silmek yerine karantinaya alır
    /// (`default.store.corrupt-<zaman>`). Veri yok edilmez, kurtarılabilir kalır.
    private static func quarantineDefaultStore() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }

        StoreQuarantine.quarantine(storeAt: appSupport.appendingPathComponent("default.store"))
    }
}
