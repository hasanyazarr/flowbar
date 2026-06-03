import Foundation

/// History grid'inde proje kartlarının sıralama ölçütü.
enum HistorySortMode: String, CaseIterable, Identifiable {
    case recent        // En son oturuma göre (yeni üstte)
    case totalTime     // Toplam loglanan süreye göre (çok üstte)
    case alphabetical  // Proje adına göre A→Z

    var id: String { rawValue }

    static func from(_ raw: String) -> HistorySortMode {
        HistorySortMode(rawValue: raw) ?? .recent
    }

    var title: String {
        switch self {
        case .recent: return String(localized: "Recent")
        case .totalTime: return String(localized: "Total time")
        case .alphabetical: return String(localized: "Alphabetical")
        }
    }
}

/// Bir projenin History grid'indeki klasörü: proje + (yeni→eski) oturumları
/// ve türetilmiş özetler. `totalSeconds` kuruluşta bir kez hesaplanır.
struct ProjectHistoryFolder: Identifiable {
    let id: UUID
    let project: Project
    let sessions: [Session]   // newest first
    let totalSeconds: Int

    var sessionCount: Int { sessions.count }
}

enum ProjectHistory {
    /// Oturumu olan aktif projeleri, seçili ölçüte göre sıralı klasörlere çevirir.
    /// Oturumu olmayan projeler hariç tutulur. Her klasörün oturumları yeni→eski.
    static func folders(projects: [Project], sort: HistorySortMode) -> [ProjectHistoryFolder] {
        let withSessions = projects.filter { !$0.sessions.isEmpty }
        let folders = withSessions.map { project in
            ProjectHistoryFolder(
                id: project.id,
                project: project,
                sessions: SessionHistory.latest(project.sessions),
                totalSeconds: project.totalLoggedSeconds
            )
        }
        return sorted(folders, by: sort)
    }

    private static func sorted(_ folders: [ProjectHistoryFolder],
                               by sort: HistorySortMode) -> [ProjectHistoryFolder] {
        switch sort {
        case .recent:
            return folders.sorted { lhs, rhs in
                let l = lhs.project.lastSessionDate ?? .distantPast
                let r = rhs.project.lastSessionDate ?? .distantPast
                return l > r
            }
        case .totalTime:
            return folders.sorted { $0.totalSeconds > $1.totalSeconds }
        case .alphabetical:
            return folders.sorted {
                $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
            }
        }
    }
}
