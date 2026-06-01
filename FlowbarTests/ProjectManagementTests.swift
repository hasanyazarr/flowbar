import XCTest
import SwiftUI
import SwiftData
@testable import Flowbar

final class ProjectManagementTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Session.self, Category.self, configurations: config)
        return ModelContext(container)
    }

    // MARK: - ProjectStatus

    func test_projectStatus_labels() {
        XCTAssertEqual(ProjectStatus.inProgress.label, "In progress")
        XCTAssertEqual(ProjectStatus.continuous.label, "Continuous")
        XCTAssertEqual(ProjectStatus.paused.label, "Paused")
        XCTAssertEqual(ProjectStatus.done.label, "Done")
    }

    func test_projectStatus_rawValueRoundTrip() {
        for s in ProjectStatus.allCases {
            XCTAssertEqual(ProjectStatus(rawValue: s.rawValue), s)
        }
    }

    func test_projectStatus_hasColor() {
        for s in ProjectStatus.allCases {
            XCTAssertFalse(s.colorHex.isEmpty)
        }
    }

    // MARK: - Color hex

    func test_colorHexRoundTrip() {
        let hex = "#E06C75"
        let color = Color(hex: hex)
        XCTAssertNotNil(color)
    }

    func test_colorHex_invalidReturnsNil() {
        XCTAssertNil(Color(hex: "nothex"))
    }

    // MARK: - Models

    func test_project_defaults() throws {
        let ctx = try makeContext()
        let p = Project(name: "X")
        ctx.insert(p)
        XCTAssertEqual(p.status, .inProgress)
        XCTAssertEqual(p.priority, 0)
        XCTAssertFalse(p.isArchived)
        XCTAssertNil(p.category)
    }

    func test_project_statusWrapper() throws {
        let ctx = try makeContext()
        let p = Project(name: "X")
        ctx.insert(p)
        p.status = .paused
        XCTAssertEqual(p.statusRaw, ProjectStatus.paused.rawValue)
        XCTAssertEqual(p.status, .paused)
    }

    func test_category_projectRelationship() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Research", colorHex: "#E06C75")
        ctx.insert(cat)
        let p = Project(name: "Splatting")
        p.category = cat
        ctx.insert(p)
        XCTAssertEqual(p.category?.name, "Research")
        XCTAssertTrue(cat.projects.contains { $0.id == p.id })
    }

    func test_categoryPalette_hasPredefinedColors() {
        XCTAssertGreaterThanOrEqual(CategoryPalette.colors.count, 8)
        XCTAssertEqual(CategoryPalette.defaultHex, CategoryPalette.colors[0])
        for hex in CategoryPalette.colors {
            XCTAssertNotNil(Color(hex: hex))
        }
    }

    func test_deleteCategory_keepsProjectsAndClearsCategory() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Research", colorHex: "#2F80ED")
        let project = Project(name: "Splatting")
        project.category = cat
        ctx.insert(cat)
        ctx.insert(project)

        CategoryManagement.delete(cat, in: ctx)
        try ctx.save()

        XCTAssertNil(project.category)
    }

    // MARK: - ProjectFiltering

    func test_filteredProjects_caseInsensitive() throws {
        let ctx = try makeContext()
        let a = Project(name: "Research: Splatting"); ctx.insert(a)
        let b = Project(name: "ITU: Circuit"); ctx.insert(b)
        let result = ProjectFiltering.filtered([a, b], query: "circuit")
        XCTAssertEqual(result.map(\.name), ["ITU: Circuit"])
    }

    func test_filteredProjects_byCategory() throws {
        let ctx = try makeContext()
        let research = Category(name: "Research", colorHex: "#2F80ED")
        let academic = Category(name: "Academic", colorHex: "#27AE60")
        ctx.insert(research); ctx.insert(academic)
        let a = Project(name: "Splatting"); a.category = research; ctx.insert(a)
        let b = Project(name: "Circuit"); b.category = academic; ctx.insert(b)
        let c = Project(name: "Uncategorized"); ctx.insert(c)

        let result = ProjectFiltering.filtered([a, b, c], categoryID: research.id)
        XCTAssertEqual(result.map(\.name), ["Splatting"])
    }

    func test_filteredProjects_nilCategoryReturnsAll() throws {
        let ctx = try makeContext()
        let cat = Category(name: "Research", colorHex: "#2F80ED"); ctx.insert(cat)
        let a = Project(name: "A"); a.category = cat; ctx.insert(a)
        let b = Project(name: "B"); ctx.insert(b)

        XCTAssertEqual(ProjectFiltering.filtered([a, b], categoryID: nil).count, 2)
    }

    func test_filteredProjects_emptyQueryReturnsAll() throws {
        let ctx = try makeContext()
        let a = Project(name: "A"); ctx.insert(a)
        let b = Project(name: "B"); ctx.insert(b)
        XCTAssertEqual(ProjectFiltering.filtered([a, b], query: "  ").count, 2)
    }

    func test_activeProjects_includesLegacyArchivedProjects() throws {
        let ctx = try makeContext()
        let active = Project(name: "Active"); ctx.insert(active)
        let archived = Project(name: "Archived"); ctx.insert(archived)
        archived.isArchived = true

        let result = ProjectFiltering.active([active, archived])

        XCTAssertEqual(result.map(\.name), ["Active", "Archived"])
    }

    func test_popoverLayout_sessionIsCompactAndProjectsIsLarger() {
        let session = PopoverLayout.sessionSize(projectRowCount: 1, recentSessionCount: 0)
        let projects = PopoverLayout.size(for: .projects)
        let history = PopoverLayout.size(for: .history)

        XCTAssertEqual(session.width, 480)
        XCTAssertEqual(projects.width, 480)
        XCTAssertEqual(history.width, 480)
        XCTAssertLessThan(session.height, projects.height)
        XCTAssertLessThan(session.height, history.height)
        XCTAssertEqual(session.height, 318)
        XCTAssertEqual(projects.height, 640)
        XCTAssertEqual(history.height, 560)
    }

    func test_popoverLayout_sessionHeightAdaptsToContent() {
        let small = PopoverLayout.sessionSize(projectRowCount: 1, recentSessionCount: 0)
        let withRecent = PopoverLayout.sessionSize(projectRowCount: 1, recentSessionCount: 2)
        let largerList = PopoverLayout.sessionSize(projectRowCount: 4, recentSessionCount: 3)

        XCTAssertGreaterThan(withRecent.height, small.height)
        XCTAssertGreaterThan(largerList.height, withRecent.height)
        XCTAssertEqual(withRecent.height, 394)
        XCTAssertLessThanOrEqual(largerList.height, PopoverLayout.sessionMaxHeight)
    }

    func test_popoverLayout_historyGrowsWhenManualFormOpen() {
        let collapsed = PopoverLayout.historySize(showsManualEntryForm: false)
        let expanded = PopoverLayout.historySize(showsManualEntryForm: true)
        XCTAssertEqual(collapsed, PopoverLayout.size(for: .history))
        XCTAssertGreaterThan(expanded.height, collapsed.height)
        XCTAssertEqual(expanded.width, collapsed.width)
    }

    func test_popoverLayout_analyticsHasGenerousSize() {
        let analytics = PopoverLayout.size(for: .analytics)
        XCTAssertEqual(analytics.width, 480)
        XCTAssertGreaterThanOrEqual(analytics.height, 560)
    }

    func test_popoverLayout_sessionDoesNotCreateProjectsAndHasLargeNoteArea() {
        XCTAssertFalse(PopoverLayout.showsInlineProjectCreation(for: .session))
        XCTAssertTrue(PopoverLayout.showsInlineProjectCreation(for: .projects))
        XCTAssertEqual(PopoverLayout.sessionNoteMinHeight, 110)
    }

    func test_popoverLayout_sessionNoteUsesPlainMultilineBullets() {
        XCTAssertTrue(PopoverLayout.sessionNotePlaceholder.contains("\n"))
        XCTAssertFalse(PopoverLayout.sessionNotePlaceholder.contains("•"))
        XCTAssertEqual(PopoverLayout.recentSessionNotesTitle, "Son oturum notları")
    }

    func test_popoverLayout_projectsUseInlineExpandedCards() {
        XCTAssertTrue(PopoverLayout.projectsUseInlineExpandedCards)
        XCTAssertFalse(PopoverLayout.projectsUseSideInspector)
    }

    func test_recencySorted_mostRecentFirst() throws {
        let ctx = try makeContext()
        let old = Project(name: "Old"); ctx.insert(old)
        let new = Project(name: "New"); ctx.insert(new)
        let s1 = Session(note: "", measuredSeconds: 60, loggedSeconds: 60,
                         startedAt: Date(timeIntervalSince1970: 1000), endedAt: .now, project: old)
        let s2 = Session(note: "", measuredSeconds: 60, loggedSeconds: 60,
                         startedAt: Date(timeIntervalSince1970: 9000), endedAt: .now, project: new)
        ctx.insert(s1); ctx.insert(s2)
        let sorted = ProjectFiltering.recencySorted([old, new])
        XCTAssertEqual(sorted.first?.name, "New")
    }

    func test_recencySorted_noSessionsGoLast() throws {
        let ctx = try makeContext()
        let withS = Project(name: "WithS"); ctx.insert(withS)
        let none = Project(name: "None"); ctx.insert(none)
        let s = Session(note: "", measuredSeconds: 60, loggedSeconds: 60,
                        startedAt: .now, endedAt: .now, project: withS)
        ctx.insert(s)
        let sorted = ProjectFiltering.recencySorted([none, withS])
        XCTAssertEqual(sorted.first?.name, "WithS")
        XCTAssertEqual(sorted.last?.name, "None")
    }

    func test_sessionSaveDraft_usesEditedNoteWhenCreatingSession() throws {
        let project = Flowbar.Project(name: "Math")

        let draft = SessionSaveDraft(note: "matematik sorusu çözüldü", hours: 1, minutes: 15)
        let started = Date(timeIntervalSince1970: 1_000)
        let ended = Date(timeIntervalSince1970: 2_000)
        let session = draft.makeSession(measuredSeconds: 70, startedAt: started, endedAt: ended, project: project)

        XCTAssertEqual(session.note, "matematik sorusu çözüldü")
        XCTAssertEqual(session.loggedSeconds, 4_500)
        XCTAssertEqual(session.startedAt, started)
        XCTAssertEqual(session.endedAt, ended)
        XCTAssertEqual(session.project?.id, project.id)
    }

    func test_sessionCompletionLayout_hasFixedDurationControlWidths() {
        XCTAssertEqual(SessionCompletionLayout.durationValueWidth, 90)
        XCTAssertEqual(SessionCompletionLayout.stepperWidth, 42)
    }

    func test_sessionHistory_latestSortsEndedAtDescending() throws {
        let ctx = try makeContext()
        let project = Project(name: "Research")
        ctx.insert(project)
        let older = Session(note: "older", measuredSeconds: 120, loggedSeconds: 60,
                            startedAt: Date(timeIntervalSince1970: 100),
                            endedAt: Date(timeIntervalSince1970: 200),
                            project: project)
        let newer = Session(note: "newer", measuredSeconds: 120, loggedSeconds: 60,
                            startedAt: Date(timeIntervalSince1970: 300),
                            endedAt: Date(timeIntervalSince1970: 400),
                            project: project)

        let result = SessionHistory.latest([older, newer])

        XCTAssertEqual(result.map(\.note), ["newer", "older"])
    }

    func test_sessionHistory_recentForProject_filtersSortsAndLimits() throws {
        let ctx = try makeContext()
        let selected = Project(name: "Selected")
        let other = Project(name: "Other")
        ctx.insert(selected)
        ctx.insert(other)

        let old = Session(note: "old", measuredSeconds: 60, loggedSeconds: 60,
                          startedAt: Date(timeIntervalSince1970: 100),
                          endedAt: Date(timeIntervalSince1970: 200),
                          project: selected)
        let middle = Session(note: "middle", measuredSeconds: 60, loggedSeconds: 60,
                             startedAt: Date(timeIntervalSince1970: 300),
                             endedAt: Date(timeIntervalSince1970: 400),
                             project: selected)
        let newest = Session(note: "newest", measuredSeconds: 60, loggedSeconds: 60,
                             startedAt: Date(timeIntervalSince1970: 500),
                             endedAt: Date(timeIntervalSince1970: 600),
                             project: selected)
        let otherSession = Session(note: "other", measuredSeconds: 60, loggedSeconds: 60,
                                   startedAt: Date(timeIntervalSince1970: 700),
                                   endedAt: Date(timeIntervalSince1970: 800),
                                   project: other)

        let result = SessionHistory.recent(for: selected.id, from: [old, middle, newest, otherSession], limit: 2)

        XCTAssertEqual(result.map(\.note), ["newest", "middle"])
    }

    // MARK: - Manuel oturum girişi

    func test_manualEntry_loggedSecondsFromHoursMinutes() {
        let entry = ManualSessionEntry(note: "tablette çalıştım", hours: 1, minutes: 30, day: .now)
        XCTAssertEqual(entry.loggedSeconds, 5_400)
    }

    func test_manualEntry_canSaveRequiresAtLeastOneMinute() {
        XCTAssertFalse(ManualSessionEntry(note: "", hours: 0, minutes: 0, day: .now).canSave)
        XCTAssertTrue(ManualSessionEntry(note: "", hours: 0, minutes: 1, day: .now).canSave)
        XCTAssertTrue(ManualSessionEntry(note: "", hours: 2, minutes: 0, day: .now).canSave)
    }

    func test_manualEntry_endsAtEndOfSelectedDay() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 9))!

        let entry = ManualSessionEntry(note: "", hours: 1, minutes: 0, day: day)
        let session = entry.makeSession(project: Project(name: "X"), calendar: cal)

        // endedAt seçilen günün son anına düşmeli (doğru güne sıralanması için)
        let endComponents = cal.dateComponents([.year, .month, .day], from: session.endedAt)
        XCTAssertEqual(endComponents.year, 2026)
        XCTAssertEqual(endComponents.month, 5)
        XCTAssertEqual(endComponents.day, 20)
    }

    func test_manualEntry_startedAtIsEndMinusDuration() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 20))!

        let entry = ManualSessionEntry(note: "", hours: 1, minutes: 30, day: day)
        let session = entry.makeSession(project: Project(name: "X"), calendar: cal)

        XCTAssertEqual(session.endedAt.timeIntervalSince(session.startedAt), 5_400, accuracy: 1)
    }

    func test_manualEntry_marksMeasuredSecondsZero() throws {
        let entry = ManualSessionEntry(note: "elle", hours: 0, minutes: 45, day: .now)
        let session = entry.makeSession(project: Project(name: "X"))

        XCTAssertEqual(session.measuredSeconds, 0)
        XCTAssertEqual(session.loggedSeconds, 2_700)
        XCTAssertEqual(session.note, "elle")
    }

    // MARK: - Oturum düzenleme

    func test_sessionEdit_loadsCurrentValues() throws {
        let project = Project(name: "Math")
        let started = Date(timeIntervalSince1970: 1_000)
        let ended = started.addingTimeInterval(5_400) // 1s 30dk
        let session = Session(note: "soru çöz", measuredSeconds: 6_000,
                              loggedSeconds: 5_400, startedAt: started, endedAt: ended, project: project)

        let edit = SessionEdit(session: session)

        XCTAssertEqual(edit.note, "soru çöz")
        XCTAssertEqual(edit.hours, 1)
        XCTAssertEqual(edit.minutes, 30)
        XCTAssertEqual(edit.projectID, project.id)
        XCTAssertEqual(edit.day, ended)
    }

    func test_sessionEdit_applyUpdatesNoteAndDuration() throws {
        let project = Project(name: "Math")
        let session = Session(note: "eski", measuredSeconds: 100, loggedSeconds: 60,
                              startedAt: Date(timeIntervalSince1970: 1_000),
                              endedAt: Date(timeIntervalSince1970: 1_060), project: project)

        var edit = SessionEdit(session: session)
        edit.note = "yeni"
        edit.hours = 2
        edit.minutes = 0
        edit.apply(to: session, project: project)

        XCTAssertEqual(session.note, "yeni")
        XCTAssertEqual(session.loggedSeconds, 7_200)
        XCTAssertEqual(session.endedAt.timeIntervalSince(session.startedAt), 7_200, accuracy: 1)
    }

    func test_sessionEdit_applyReassignsProject() throws {
        let oldProject = Project(name: "Old")
        let newProject = Project(name: "New")
        let session = Session(note: "", measuredSeconds: 0, loggedSeconds: 3_600,
                              startedAt: Date(timeIntervalSince1970: 1_000),
                              endedAt: Date(timeIntervalSince1970: 4_600), project: oldProject)

        var edit = SessionEdit(session: session)
        edit.projectID = newProject.id
        edit.apply(to: session, project: newProject)

        XCTAssertEqual(session.project?.id, newProject.id)
    }

    func test_sessionEdit_applyPreservesMeasuredSeconds() throws {
        let project = Project(name: "X")
        let session = Session(note: "", measuredSeconds: 999, loggedSeconds: 60,
                              startedAt: Date(timeIntervalSince1970: 1_000),
                              endedAt: Date(timeIntervalSince1970: 1_060), project: project)

        var edit = SessionEdit(session: session)
        edit.minutes = 30
        edit.apply(to: session, project: project)

        XCTAssertEqual(session.measuredSeconds, 999)
    }

    func test_sessionEdit_canSaveRequiresAtLeastOneMinute() throws {
        let project = Project(name: "X")
        let session = Session(note: "", measuredSeconds: 0, loggedSeconds: 60,
                              startedAt: .now, endedAt: .now, project: project)
        var edit = SessionEdit(session: session)
        edit.hours = 0; edit.minutes = 0
        XCTAssertFalse(edit.canSave)
        edit.minutes = 15
        XCTAssertTrue(edit.canSave)
    }

    // MARK: - Analytics: period filtering + summary

    private func session(_ logged: Int, endedAt: Date, project: Project? = nil) -> Session {
        Session(note: "", measuredSeconds: 0, loggedSeconds: logged,
                startedAt: endedAt.addingTimeInterval(-Double(logged)), endedAt: endedAt, project: project)
    }

    func test_analytics_summaryAggregatesTotalsAndAverage() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            session(3_600, endedAt: now),
            session(1_800, endedAt: now.addingTimeInterval(-100)),
        ]
        let summary = Analytics.summary(sessions)
        XCTAssertEqual(summary.totalSeconds, 5_400)
        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.averageSeconds, 2_700)
    }

    func test_analytics_summaryEmptyIsZeroNoDivideByZero() {
        let summary = Analytics.summary([])
        XCTAssertEqual(summary, AnalyticsSummary(totalSeconds: 0, sessionCount: 0, averageSeconds: 0))
    }

    func test_analytics_summaryAverageTruncatesTowardZero() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [session(60, endedAt: now), session(60, endedAt: now), session(61, endedAt: now)]
        let summary = Analytics.summary(sessions)
        XCTAssertEqual(summary.totalSeconds, 181)
        XCTAssertEqual(summary.averageSeconds, 60) // 181 / 3 = 60.33 -> 60
    }

    func test_analytics_filterWeekKeepsOnlyCurrentWeek() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12))!
        let inWeek = session(60, endedAt: cal.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!)
        let lastWeek = session(60, endedAt: cal.date(from: DateComponents(year: 2026, month: 5, day: 20))!)

        let result = Analytics.filter([inWeek, lastWeek], period: .week, now: now, calendar: cal)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.loggedSeconds, 60)
    }

    func test_analytics_filterMonthKeepsOnlyCurrentMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3))!
        let inMonth = session(60, endedAt: cal.date(from: DateComponents(year: 2026, month: 6, day: 28))!)
        let lastMonth = session(60, endedAt: cal.date(from: DateComponents(year: 2026, month: 5, day: 30))!)

        let result = Analytics.filter([inMonth, lastMonth], period: .month, now: now, calendar: cal)
        XCTAssertEqual(result.count, 1)
    }

    func test_analytics_filterAllKeepsEverything() {
        let now = Date()
        let a = session(60, endedAt: now)
        let b = session(60, endedAt: now.addingTimeInterval(-10_000_000))
        XCTAssertEqual(Analytics.filter([a, b], period: .all, now: now).count, 2)
    }

    func test_analyticsPeriod_labels() {
        XCTAssertEqual(AnalyticsPeriod.week.label, "Hafta")
        XCTAssertEqual(AnalyticsPeriod.month.label, "Ay")
        XCTAssertEqual(AnalyticsPeriod.all.label, "Tümü")
    }

    // MARK: - Analytics: category + project totals

    func test_analytics_categoryTotalsSortedDescendingWithColor() throws {
        let ctx = try makeContext()
        let academic = Category(name: "Academic", colorHex: "#27AE60"); ctx.insert(academic)
        let research = Category(name: "Research", colorHex: "#2F80ED"); ctx.insert(research)
        let pA = Project(name: "A"); pA.category = academic; ctx.insert(pA)
        let pR = Project(name: "R"); pR.category = research; ctx.insert(pR)
        let now = Date()
        let sessions = [
            session(3_600, endedAt: now, project: pA),
            session(1_800, endedAt: now, project: pA),
            session(7_200, endedAt: now, project: pR),
        ]

        let totals = Analytics.categoryTotals(sessions)

        XCTAssertEqual(totals.map(\.name), ["Research", "Academic"])
        XCTAssertEqual(totals.first?.totalSeconds, 7_200)
        XCTAssertEqual(totals.first?.colorHex, "#2F80ED")
        XCTAssertEqual(totals.last?.totalSeconds, 5_400)
    }

    func test_analytics_categoryTotalsGroupsUncategorized() throws {
        let ctx = try makeContext()
        let p = Project(name: "NoCat"); ctx.insert(p)
        let now = Date()
        let totals = Analytics.categoryTotals([session(600, endedAt: now, project: p)])
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.first?.name, "Kategorisiz")
        XCTAssertEqual(totals.first?.colorHex, "#828282")
    }

    func test_analytics_projectTotalsSortedAndLimited() throws {
        let ctx = try makeContext()
        let p1 = Project(name: "One"); ctx.insert(p1)
        let p2 = Project(name: "Two"); ctx.insert(p2)
        let p3 = Project(name: "Three"); ctx.insert(p3)
        let now = Date()
        let sessions = [
            session(1_000, endedAt: now, project: p1),
            session(5_000, endedAt: now, project: p2),
            session(3_000, endedAt: now, project: p3),
        ]

        let totals = Analytics.projectTotals(sessions, limit: 2)

        XCTAssertEqual(totals.map(\.name), ["Two", "Three"])
        XCTAssertEqual(totals.first?.totalSeconds, 5_000)
    }

    func test_analytics_projectTotalsIgnoresSessionsWithoutProject() {
        let now = Date()
        let orphan = session(1_000, endedAt: now, project: nil)
        XCTAssertTrue(Analytics.projectTotals([orphan], limit: 5).isEmpty)
    }

    // MARK: - Analytics: trend buckets

    private var istanbul: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return cal
    }

    func test_analytics_weekTrendHasSevenDailyBuckets() {
        let cal = istanbul
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12))!
        let buckets = Analytics.trend([], period: .week, now: now, calendar: cal)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertTrue(zip(buckets, buckets.dropFirst()).allSatisfy { $0.start < $1.start })
    }

    func test_analytics_weekTrendSumsIntoCorrectDay() {
        let cal = istanbul
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12))!
        let onJun2 = session(3_600, endedAt: cal.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 10))!)
        let buckets = Analytics.trend([onJun2], period: .week, now: now, calendar: cal)
        let total = buckets.reduce(0) { $0 + $1.totalSeconds }
        XCTAssertEqual(total, 3_600)
        let jun2Bucket = buckets.first { cal.isDate($0.start, inSameDayAs: cal.date(from: DateComponents(year: 2026, month: 6, day: 2))!) }
        XCTAssertEqual(jun2Bucket?.totalSeconds, 3_600)
    }

    func test_analytics_monthTrendBucketsAreWeeks() {
        let cal = istanbul
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let buckets = Analytics.trend([], period: .month, now: now, calendar: cal)
        XCTAssertGreaterThanOrEqual(buckets.count, 4)
        XCTAssertLessThanOrEqual(buckets.count, 6)
        XCTAssertTrue(zip(buckets, buckets.dropFirst()).allSatisfy { $0.start < $1.start })
    }

    func test_analytics_allTrendBucketsAreMonthsCoveringDataRange() {
        let cal = istanbul
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let jan = session(600, endedAt: cal.date(from: DateComponents(year: 2026, month: 1, day: 5))!)
        let mar = session(600, endedAt: cal.date(from: DateComponents(year: 2026, month: 3, day: 5))!)
        let buckets = Analytics.trend([jan, mar], period: .all, now: now, calendar: cal)
        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets.map(\.totalSeconds), [600, 0, 600])
    }

    func test_analytics_allTrendEmptyWhenNoSessions() {
        XCTAssertTrue(Analytics.trend([], period: .all, now: Date(), calendar: istanbul).isEmpty)
    }
}
