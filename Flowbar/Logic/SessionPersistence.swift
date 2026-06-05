import Foundation
import SwiftData

/// Oturum ekleme/silme işlemlerini diske **hemen** yazan tek giriş noktası.
///
/// Geçmişte view'lar `context.insert` çağırıp kaydı SwiftData'nın autosave'ine
/// bırakıyordu. Menubar uygulamasında popover kapanışı / app suspend / migration
/// araya girdiğinde autosave penceresi kaçabildiği için oturumlar diske yazılmadan
/// kayboluyordu. Bu yardımcı her işlemden sonra açık `try context.save()` yapar.
enum SessionPersistence {
    /// Yeni oturumu ekler ve **hemen** kalıcılaştırır.
    static func commit(_ session: Session, in context: ModelContext) throws {
        context.insert(session)
        try context.save()
    }

    /// Oturumu siler ve **hemen** kalıcılaştırır.
    static func delete(_ session: Session, in context: ModelContext) throws {
        context.delete(session)
        try context.save()
    }

    /// Bekleyen değişiklikleri diske yazar. insert/delete sonrası çağrılmalı.
    /// Autosave'e güvenmek menubar uygulamasında veri kaybına yol açıyordu.
    static func save(_ context: ModelContext) {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
