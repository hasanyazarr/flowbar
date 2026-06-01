import XCTest
import SwiftData
@testable import Flowbar

final class ReminderTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Reminder.self, configurations: config)
        return ModelContext(container)
    }

    func test_reminder_initializationDefaults() throws {
        let ctx = try makeContext()
        let project = Project(name: "Test Project")
        ctx.insert(project)

        let reminder = Reminder(content: "Test task content", remindAt: nil, project: project)
        ctx.insert(reminder)

        XCTAssertNotNil(reminder.id)
        XCTAssertEqual(reminder.content, "Test task content")
        XCTAssertNil(reminder.remindAt)
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertEqual(reminder.project?.name, "Test Project")
    }

    func test_reminder_withTargetTime() throws {
        let ctx = try makeContext()
        let targetDate = Date().addingTimeInterval(3600)
        let reminder = Reminder(content: "Finish PR review", remindAt: targetDate, project: nil)
        ctx.insert(reminder)

        XCTAssertEqual(reminder.remindAt, targetDate)
        XCTAssertFalse(reminder.isCompleted)
    }

    func test_reminder_completionToggle() throws {
        let ctx = try makeContext()
        let reminder = Reminder(content: "Do sports", remindAt: nil, project: nil)
        ctx.insert(reminder)

        XCTAssertFalse(reminder.isCompleted)
        reminder.isCompleted = true
        XCTAssertTrue(reminder.isCompleted)
    }

    func test_project_cascadeDeletesReminders() throws {
        // ModelContainer for both models is configured in makeContext
        let ctx = try makeContext()
        let project = Project(name: "Delete Me")
        ctx.insert(project)

        let r1 = Reminder(content: "Subtask 1", remindAt: nil, project: project)
        let r2 = Reminder(content: "Subtask 2", remindAt: nil, project: project)
        ctx.insert(r1)
        ctx.insert(r2)

        XCTAssertEqual(project.reminders.count, 2)

        // Delete project
        ctx.delete(project)
        try ctx.save()

        // Fetch remaining reminders
        let descriptor = FetchDescriptor<Reminder>()
        let remainingReminders = try ctx.fetch(descriptor)

        XCTAssertTrue(remainingReminders.isEmpty, "Cascade delete should remove associated reminders.")
    }
}
