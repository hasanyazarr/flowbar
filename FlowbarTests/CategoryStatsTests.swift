import XCTest
import SwiftData
@testable import Flowbar

final class CategoryStatsTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Session.self, Category.self, configurations: config)
        return ModelContext(container)
    }

    // Builds a project with N logged sessions of `seconds` each, optional category.
    @discardableResult
    private func makeProject(_ name: String, category: Category?, sessionSeconds: [Int],
                             in context: ModelContext) -> Project {
        let p = Project(name: name)
        p.category = category
        context.insert(p)
        for s in sessionSeconds {
            let session = Session(note: "", measuredSeconds: s, loggedSeconds: s,
                                  startedAt: .now, endedAt: .now, project: p)
            context.insert(session)
        }
        return p
    }

    func test_folders_groupByCategory_withUncategorized() throws {
        let ctx = try makeContext()
        let academic = Category(name: "Academic", colorHex: "#98C379")
        ctx.insert(academic)
        makeProject("A", category: academic, sessionSeconds: [3600], in: ctx)       // 1h
        makeProject("B", category: academic, sessionSeconds: [1800], in: ctx)       // 0.5h
        makeProject("C", category: nil, sessionSeconds: [900], in: ctx)             // 0.25h

        let folders = CategoryStats.folders(projects: [
            try XCTUnwrap(fetch("A", ctx)),
            try XCTUnwrap(fetch("B", ctx)),
            try XCTUnwrap(fetch("C", ctx)),
        ])

        // Two folders: Academic (2 projects, 5400s) and Uncategorized (1 project, 900s)
        XCTAssertEqual(folders.count, 2)
        let academicFolder = try XCTUnwrap(folders.first { $0.name == "Academic" })
        XCTAssertEqual(academicFolder.projectCount, 2)
        XCTAssertEqual(academicFolder.totalSeconds, 5400)
        let uncategorized = try XCTUnwrap(folders.first { $0.name == Analytics.uncategorizedName })
        XCTAssertEqual(uncategorized.projectCount, 1)
        XCTAssertEqual(uncategorized.totalSeconds, 900)
        XCTAssertEqual(uncategorized.colorHex, Analytics.uncategorizedHex)
    }

    func test_folders_empty() {
        XCTAssertTrue(CategoryStats.folders(projects: []).isEmpty)
    }

    func test_folders_allUncategorized() throws {
        let ctx = try makeContext()
        let p1 = makeProject("A", category: nil, sessionSeconds: [600], in: ctx)
        let p2 = makeProject("B", category: nil, sessionSeconds: [300], in: ctx)

        let folders = CategoryStats.folders(projects: [p1, p2])

        XCTAssertEqual(folders.count, 1)
        let folder = try XCTUnwrap(folders.first)
        XCTAssertEqual(folder.id, .uncategorized)
        XCTAssertEqual(folder.projectCount, 2)
        XCTAssertEqual(folder.totalSeconds, 900)
    }

    func test_folders_noneUncategorized_noTrailingBucket() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Work", colorHex: "#61AFEF")
        ctx.insert(cat)
        let p1 = makeProject("A", category: cat, sessionSeconds: [600], in: ctx)
        let p2 = makeProject("B", category: cat, sessionSeconds: [300], in: ctx)

        let folders = CategoryStats.folders(projects: [p1, p2])

        XCTAssertEqual(folders.count, 1)
        XCTAssertNil(folders.first { $0.id == .uncategorized })
    }

    func test_folders_alphabeticalSort_uncategorizedLast() throws {
        let ctx = try makeContext()
        let zzz = Category(name: "Zzz", colorHex: "#E06C75")
        let aaa = Category(name: "Aaa", colorHex: "#98C379")
        ctx.insert(zzz); ctx.insert(aaa)
        // Kasıtlı olarak alfabetik olmayan ekleme sırası + bir kategorisiz.
        let pz = makeProject("PZ", category: zzz, sessionSeconds: [100], in: ctx)
        let pa = makeProject("PA", category: aaa, sessionSeconds: [100], in: ctx)
        let pu = makeProject("PU", category: nil, sessionSeconds: [100], in: ctx)

        let folders = CategoryStats.folders(projects: [pz, pa, pu])

        XCTAssertEqual(folders.map(\.name), ["Aaa", "Zzz", Analytics.uncategorizedName])
        XCTAssertEqual(folders.last?.id, .uncategorized)
    }

    private func fetch(_ name: String, _ ctx: ModelContext) throws -> Project? {
        try ctx.fetch(FetchDescriptor<Project>()).first { $0.name == name }
    }
}
