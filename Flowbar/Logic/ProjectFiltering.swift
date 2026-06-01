import Foundation

enum ProjectFiltering {
    static func active(_ projects: [Project]) -> [Project] {
        projects
    }

    /// İsimde (case-insensitive) query geçen projeler. Boş/whitespace query tümünü döner.
    static func filtered(_ projects: [Project], query: String) -> [Project] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return projects }
        return projects.filter { $0.name.range(of: q, options: .caseInsensitive) != nil }
    }

    /// Belirli bir kategorideki projeler. categoryID nil ise tümünü döner.
    static func filtered(_ projects: [Project], categoryID: UUID?) -> [Project] {
        guard let categoryID else { return projects }
        return projects.filter { $0.category?.id == categoryID }
    }

    /// En son oturum tarihine göre azalan; hiç oturumu olmayanlar en sona.
    static func recencySorted(_ projects: [Project]) -> [Project] {
        projects.sorted { lhs, rhs in
            switch (lhs.lastSessionDate, rhs.lastSessionDate) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.name < rhs.name
            }
        }
    }
}

enum SessionHistory {
    static func latest(_ sessions: [Session]) -> [Session] {
        sessions.sorted { lhs, rhs in
            lhs.endedAt > rhs.endedAt
        }
    }

    static func recent(for projectID: UUID?, from sessions: [Session], limit: Int = 3) -> [Session] {
        guard let projectID else { return [] }
        return latest(sessions.filter { $0.project?.id == projectID })
            .prefix(limit)
            .map { $0 }
    }
}
