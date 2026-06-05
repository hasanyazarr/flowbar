import XCTest
import SwiftData
@testable import Flowbar

private typealias Category = Flowbar.Category

/// Veri kaybı regresyon testleri.
/// Geçmişte oturumlar `context.insert` ile eklenip hiç `save()` çağrılmadığı için
/// autosave'in kaçırdığı durumlarda (popover kapanışı, app suspend, migration)
/// diske yazılmadan kayboluyordu. Bu testler kaydetmenin gerçekten kalıcı
/// olduğunu garanti eder.
final class SessionPersistenceTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Project.self, Session.self, Category.self, Reminder.self,
            configurations: config
        )
        return ModelContext(container)
    }

    func test_commitDraft_persistsSessionImmediately() throws {
        let ctx = try makeContext()
        let project = Project(name: "Coding")
        ctx.insert(project)

        let draft = SessionSaveDraft(note: "Implemented save fix", hours: 1, minutes: 30)
        try SessionPersistence.commit(
            draft.makeSession(measuredSeconds: 5400, startedAt: .now, endedAt: .now, project: project),
            in: ctx
        )

        // hasChanges false olmalı: insert sonrası save gerçekten yazıldı.
        XCTAssertFalse(ctx.hasChanges, "Save sonrası context'te yazılmamış değişiklik kalmamalı")

        let fetched = try ctx.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.loggedSeconds, 5400)
    }

    func test_deleteSession_persistsImmediately() throws {
        let ctx = try makeContext()
        let project = Project(name: "Coding")
        ctx.insert(project)
        let session = Session(note: "x", measuredSeconds: 600, loggedSeconds: 600,
                              startedAt: .now, endedAt: .now, project: project)
        try SessionPersistence.commit(session, in: ctx)

        try SessionPersistence.delete(session, in: ctx)

        XCTAssertFalse(ctx.hasChanges, "Delete sonrası yazılmamış değişiklik kalmamalı")
        let fetched = try ctx.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(fetched.isEmpty)
    }
}
