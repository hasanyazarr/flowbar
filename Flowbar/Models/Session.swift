import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var note: String
    var measuredSeconds: Int
    var loggedSeconds: Int
    var startedAt: Date
    var endedAt: Date
    /// Kaydın oluşturulma zamanı. Geçmiş listesinde aynı güne düşen oturumları
    /// (özellikle elle eklenenleri) ekleme sırasına göre ayırmak için kullanılır.
    /// Eski kayıtlar için endedAt'e eşit varsayılır (lightweight migration).
    var createdAt: Date = Date.now
    var project: Project?

    init(note: String, measuredSeconds: Int, loggedSeconds: Int,
         startedAt: Date, endedAt: Date, project: Project?) {
        self.id = UUID()
        self.note = note
        self.measuredSeconds = measuredSeconds
        self.loggedSeconds = loggedSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = .now
        self.project = project
    }
}
