import Foundation

enum AnalyticsPeriod: String, CaseIterable {
    case week, month, all

    var label: String {
        switch self {
        case .week: return "Hafta"
        case .month: return "Ay"
        case .all: return "Tümü"
        }
    }
}

struct AnalyticsSummary: Equatable {
    let totalSeconds: Int
    let sessionCount: Int
    let averageSeconds: Int
}

enum Analytics {
    /// Seçili periyoda göre oturumları süzer. .all hepsini döner.
    static func filter(_ sessions: [Session], period: AnalyticsPeriod,
                       now: Date = .now, calendar: Calendar = .current) -> [Session] {
        switch period {
        case .all:
            return sessions
        case .week:
            return inSameComponent(sessions, now: now, calendar: calendar, granularity: .weekOfYear)
        case .month:
            return inSameComponent(sessions, now: now, calendar: calendar, granularity: .month)
        }
    }

    private static func inSameComponent(_ sessions: [Session], now: Date,
                                        calendar: Calendar, granularity: Calendar.Component) -> [Session] {
        sessions.filter { calendar.isDate($0.endedAt, equalTo: now, toGranularity: granularity) }
    }

    static func summary(_ sessions: [Session]) -> AnalyticsSummary {
        let total = sessions.reduce(0) { $0 + $1.loggedSeconds }
        let count = sessions.count
        let avg = count == 0 ? 0 : total / count
        return AnalyticsSummary(totalSeconds: total, sessionCount: count, averageSeconds: avg)
    }

    static let uncategorizedName = "Kategorisiz"
    static let uncategorizedHex = "#828282"

    static func categoryTotals(_ sessions: [Session]) -> [CategoryTotal] {
        var byName: [String: (hex: String, seconds: Int)] = [:]
        for s in sessions {
            let name = s.project?.category?.name ?? uncategorizedName
            let hex = s.project?.category?.colorHex ?? uncategorizedHex
            byName[name, default: (hex, 0)].seconds += s.loggedSeconds
        }
        return byName
            .map { CategoryTotal(name: $0.key, colorHex: $0.value.hex, totalSeconds: $0.value.seconds) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// Periyoda göre zaman kovaları üretir: hafta→son 7 gün, ay→haftalar, tümü→aylar.
    static func trend(_ sessions: [Session], period: AnalyticsPeriod,
                      now: Date = .now, calendar: Calendar = .current) -> [TrendBucket] {
        switch period {
        case .week:
            return dailyBuckets(sessions, now: now, calendar: calendar)
        case .month:
            return weeklyBuckets(sessions, now: now, calendar: calendar)
        case .all:
            return monthlyBuckets(sessions, calendar: calendar)
        }
    }

    private static func dailyBuckets(_ sessions: [Session], now: Date, calendar: Calendar) -> [TrendBucket] {
        let today = calendar.startOfDay(for: now)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
        return days.map { day in
            let total = sessions
                .filter { calendar.isDate($0.endedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.loggedSeconds }
            return TrendBucket(start: day, label: shortDay(day), totalSeconds: total)
        }
    }

    private static func weeklyBuckets(_ sessions: [Session], now: Date, calendar: Calendar) -> [TrendBucket] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
        var weekStarts: [Date] = []
        var cursor = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start ?? monthInterval.start
        while cursor < monthInterval.end {
            weekStarts.append(cursor)
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? monthInterval.end
        }
        return weekStarts.map { weekStart in
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
            let total = sessions
                .filter { $0.endedAt >= weekStart && $0.endedAt < weekEnd }
                .reduce(0) { $0 + $1.loggedSeconds }
            return TrendBucket(start: weekStart, label: shortDay(weekStart), totalSeconds: total)
        }
    }

    private static func monthlyBuckets(_ sessions: [Session], calendar: Calendar) -> [TrendBucket] {
        guard let earliest = sessions.map(\.endedAt).min(),
              let latest = sessions.map(\.endedAt).max() else { return [] }
        let firstMonth = calendar.dateInterval(of: .month, for: earliest)?.start ?? earliest
        let lastMonth = calendar.dateInterval(of: .month, for: latest)?.start ?? latest
        var months: [Date] = []
        var cursor = firstMonth
        while cursor <= lastMonth {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? lastMonth.addingTimeInterval(1)
        }
        return months.map { monthStart in
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            let total = sessions
                .filter { $0.endedAt >= monthStart && $0.endedAt < monthEnd }
                .reduce(0) { $0 + $1.loggedSeconds }
            return TrendBucket(start: monthStart, label: shortMonth(monthStart), totalSeconds: total)
        }
    }

    private static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "tr_TR")))
    }

    private static func shortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "tr_TR")))
    }

    static func projectTotals(_ sessions: [Session], limit: Int) -> [ProjectTotal] {
        var byID: [UUID: (name: String, seconds: Int)] = [:]
        for s in sessions {
            guard let project = s.project else { continue }
            byID[project.id, default: (project.name, 0)].seconds += s.loggedSeconds
        }
        return byID
            .map { ProjectTotal(id: $0.key, name: $0.value.name, totalSeconds: $0.value.seconds) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
            .prefix(limit)
            .map { $0 }
    }
}

struct TrendBucket: Identifiable, Equatable {
    var id: Date { start }
    let start: Date
    let label: String
    let totalSeconds: Int
}

struct CategoryTotal: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let colorHex: String
    let totalSeconds: Int
}

struct ProjectTotal: Identifiable, Equatable {
    let id: UUID
    let name: String
    let totalSeconds: Int
}
