import XCTest
import SwiftData
@testable import Flowbar

final class ProjectHistoryTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Session.self, Category.self, configurations: config)
        return ModelContext(container)
    }

    @discardableResult
    private func makeProject(_ name: String, in ctx: ModelContext,
                             sessions: [(logged: Int, started: Date)]) -> Project {
        let p = Project(name: name)
        ctx.insert(p)
        for s in sessions {
            // endedAt = started + süre: SessionHistory.latest endedAt'e göre
            // sıraladığı için gerçekçi bitiş zamanı kullanmak sıralamayı
            // gerçekten sınar (başlangıçla aynı olunca fark görünmezdi).
            let ended = s.started.addingTimeInterval(Double(s.logged))
            let session = Session(note: "", measuredSeconds: s.logged, loggedSeconds: s.logged,
                                  startedAt: s.started, endedAt: ended, project: p)
            ctx.insert(session)
        }
        return p
    }

    func test_folders_onlyProjectsWithSessions_sortedByRecent() throws {
        let ctx = try makeContext()
        let now = Date.now
        let older = now.addingTimeInterval(-10_000)
        let pA = makeProject("A", in: ctx, sessions: [(600, older)])
        let pB = makeProject("B", in: ctx, sessions: [(300, now)])
        let pEmpty = makeProject("Empty", in: ctx, sessions: [])

        let folders = ProjectHistory.folders(projects: [pA, pB, pEmpty], sort: .recent)
        XCTAssertEqual(folders.map(\.project.name), ["B", "A"])
        XCTAssertEqual(folders[0].sessionCount, 1)
        XCTAssertEqual(folders[1].totalSeconds, 600)
    }

    func test_folders_sortedByTotalTime() throws {
        let ctx = try makeContext()
        let now = Date.now
        let pSmall = makeProject("Small", in: ctx, sessions: [(300, now)])
        let pBig = makeProject("Big", in: ctx, sessions: [(1000, now), (500, now)])
        let folders = ProjectHistory.folders(projects: [pSmall, pBig], sort: .totalTime)
        XCTAssertEqual(folders.map(\.project.name), ["Big", "Small"])
    }

    func test_folders_sortedAlphabetically() throws {
        let ctx = try makeContext()
        let now = Date.now
        let pZ = makeProject("Zeta", in: ctx, sessions: [(100, now)])
        let pA = makeProject("Alpha", in: ctx, sessions: [(100, now)])
        let folders = ProjectHistory.folders(projects: [pZ, pA], sort: .alphabetical)
        XCTAssertEqual(folders.map(\.project.name), ["Alpha", "Zeta"])
    }

    func test_folder_sessionsAreNewestFirst() throws {
        let ctx = try makeContext()
        let now = Date.now
        let earlier = now.addingTimeInterval(-1000)
        let p = makeProject("P", in: ctx, sessions: [(100, earlier), (200, now)])
        let folder = try XCTUnwrap(ProjectHistory.folders(projects: [p], sort: .recent).first)
        XCTAssertEqual(folder.sessions.first?.loggedSeconds, 200)
        XCTAssertEqual(folder.sessions.count, 2)
    }
}
