import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Session.project)
    var sessions: [Session]
    @Relationship(deleteRule: .cascade, inverse: \Reminder.project)
    var reminders: [Reminder]
    var category: Category?
    // Inline default değerler: var olan store'lara yeni alan eklendiğinde SwiftData
    // lightweight migration'da bu default'ları kullanır (yoksa migration patlar).
    var statusRaw: String = ProjectStatus.inProgress.rawValue
    var priority: Int = 0
    var isArchived: Bool = false

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.sessions = []
        self.reminders = []
        self.category = nil
        self.statusRaw = ProjectStatus.inProgress.rawValue
        self.priority = 0
        self.isArchived = false
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    var totalLoggedSeconds: Int {
        sessions.reduce(0) { $0 + $1.loggedSeconds }
    }

    /// En son oturumun başlangıç tarihi (sıralama için); hiç oturum yoksa nil.
    var lastSessionDate: Date? {
        sessions.map(\.startedAt).max()
    }
}
