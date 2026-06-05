import XCTest
import SwiftData
@testable import Flowbar

/// Proje arşivleme (tamamlama) mantığının testleri.
final class ProjectArchiveTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Session.self, configurations: config)
        return ModelContext(container)
    }

    // MARK: - active / completed ayrımı

    func test_activeExcludesArchived() {
        let a = Project(name: "Active")
        let b = Project(name: "Done"); b.isArchived = true
        XCTAssertEqual(ProjectArchive.active([a, b]).map(\.name), ["Active"])
    }

    func test_completedIncludesOnlyArchived_sortedByCompletedAtDescending() {
        let older = Project(name: "Older")
        older.isArchived = true
        older.completedAt = Date(timeIntervalSince1970: 1000)
        let newer = Project(name: "Newer")
        newer.isArchived = true
        newer.completedAt = Date(timeIntervalSince1970: 2000)
        let active = Project(name: "Active")

        let completed = ProjectArchive.completed([older, newer, active])
        XCTAssertEqual(completed.map(\.name), ["Newer", "Older"])
    }

    // MARK: - archive: retrospektifi yazar, completedAt damgalar, isArchived=true

    func test_archive_setsArchivedAndCompletedAtAndRetro() {
        let p = Project(name: "Project")
        p.status = .done

        ProjectArchive.archive(p, outcome: "Shipped v1", learnings: "Ship earlier", now: Date(timeIntervalSince1970: 5000))

        XCTAssertTrue(p.isArchived)
        XCTAssertEqual(p.completedAt, Date(timeIntervalSince1970: 5000))
        XCTAssertEqual(p.retroOutcome, "Shipped v1")
        XCTAssertEqual(p.retroLearnings, "Ship earlier")
        XCTAssertEqual(p.status, .done, "Arşivleme status'ü done yapar/korur")
    }

    func test_archive_forcesStatusToDone() {
        let p = Project(name: "Project")
        p.status = .inProgress
        ProjectArchive.archive(p, outcome: "", learnings: "", now: .now)
        XCTAssertEqual(p.status, .done)
    }

    // MARK: - unarchive: aktife geri al, retrospektifi koru

    func test_unarchive_returnsToActiveButKeepsRetro() {
        let p = Project(name: "Project")
        ProjectArchive.archive(p, outcome: "X", learnings: "Y", now: .now)

        ProjectArchive.unarchive(p)

        XCTAssertFalse(p.isArchived)
        XCTAssertNil(p.completedAt)
        XCTAssertEqual(p.retroOutcome, "X", "Geri alınca retrospektif silinmez")
        XCTAssertEqual(p.retroLearnings, "Y")
    }

    // MARK: - normalizeLegacyArchives: completedAt'i olmayan eski archived'ları aktife alır

    func test_normalize_returnsLegacyArchivedToActive() {
        let legacy = Project(name: "Legacy")     // eski: archived ama completedAt yok
        legacy.isArchived = true
        legacy.completedAt = nil
        let proper = Project(name: "Proper")      // doğru: archived + completedAt
        proper.isArchived = true
        proper.completedAt = Date(timeIntervalSince1970: 1000)

        let changed = ProjectArchive.normalizeLegacyArchives([legacy, proper])

        XCTAssertTrue(changed, "En az bir kalıntı düzeltildiğinde true döner")
        XCTAssertFalse(legacy.isArchived, "completedAt'i olmayan archived aktife döner")
        XCTAssertTrue(proper.isArchived, "Düzgün arşivlenmiş olan korunur")
    }

    func test_normalize_noChangeWhenAllValid() {
        let a = Project(name: "A")
        let b = Project(name: "B"); b.isArchived = true; b.completedAt = .now
        XCTAssertFalse(ProjectArchive.normalizeLegacyArchives([a, b]))
    }
}
