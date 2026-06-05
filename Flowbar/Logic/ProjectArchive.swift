import Foundation

/// Proje tamamlama/arşivleme mantığı (saf, test edilebilir).
/// İki aşamalı akış: önce status `.done`, sonra `archive` ile Completed görünümüne taşınır.
enum ProjectArchive {
    /// Aktif (arşivlenmemiş) projeler.
    static func active(_ projects: [Project]) -> [Project] {
        projects.filter { !$0.isArchived }
    }

    /// Tamamlanmış (arşivlenmiş) projeler, en son tamamlanan en üstte.
    static func completed(_ projects: [Project]) -> [Project] {
        projects
            .filter { $0.isArchived }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Projeyi arşivler: retrospektifi yazar, completedAt damgalar, status'ü done yapar.
    static func archive(_ project: Project, outcome: String, learnings: String, now: Date) {
        project.retroOutcome = outcome
        project.retroLearnings = learnings
        project.status = .done
        project.completedAt = now
        project.isArchived = true
    }

    /// Arşivden çıkarır: aktife döner, completedAt temizlenir, retrospektif KORUNUR.
    static func unarchive(_ project: Project) {
        project.isArchived = false
        project.completedAt = nil
    }

    /// Eski/kalıntı veri temizliği: `isArchived` olup `completedAt`'i olmayan projeler
    /// (bu özellikten önceki arşivleme kalıntıları) aktife döndürülür. Tek tutarlı
    /// tanım: archived ⟺ tamamlandı (completedAt damgalı). Değişiklik olduysa true döner.
    @discardableResult
    static func normalizeLegacyArchives(_ projects: [Project]) -> Bool {
        var changed = false
        for project in projects where project.isArchived && project.completedAt == nil {
            project.isArchived = false
            changed = true
        }
        return changed
    }
}
