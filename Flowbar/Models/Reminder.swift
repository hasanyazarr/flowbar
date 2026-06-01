import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var content: String
    var createdAt: Date
    var remindAt: Date?
    var isCompleted: Bool
    var project: Project?

    init(content: String, remindAt: Date? = nil, project: Project? = nil) {
        self.id = UUID()
        self.content = content
        self.createdAt = .now
        self.remindAt = remindAt
        self.isCompleted = false
        self.project = project
    }
}
