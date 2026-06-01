import XCTest
import SwiftData
@testable import Flowbar

final class ModelTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Session.self, configurations: config)
        return ModelContext(container)
    }

    func test_totalLoggedSeconds_sumsSessions() throws {
        let ctx = try makeContext()
        let p = Project(name: "Coding")
        ctx.insert(p)
        let s1 = Session(note: "a", measuredSeconds: 5000, loggedSeconds: 4980,
                         startedAt: .now, endedAt: .now, project: p)
        let s2 = Session(note: "b", measuredSeconds: 700, loggedSeconds: 600,
                         startedAt: .now, endedAt: .now, project: p)
        ctx.insert(s1); ctx.insert(s2)
        XCTAssertEqual(p.totalLoggedSeconds, 5580)
    }

    func test_emptyProject_totalIsZero() throws {
        let ctx = try makeContext()
        let p = Project(name: "Empty")
        ctx.insert(p)
        XCTAssertEqual(p.totalLoggedSeconds, 0)
    }
}
