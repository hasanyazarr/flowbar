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
    var project: Project?

    init(note: String, measuredSeconds: Int, loggedSeconds: Int,
         startedAt: Date, endedAt: Date, project: Project?) {
        self.id = UUID()
        self.note = note
        self.measuredSeconds = measuredSeconds
        self.loggedSeconds = loggedSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.project = project
    }
}
