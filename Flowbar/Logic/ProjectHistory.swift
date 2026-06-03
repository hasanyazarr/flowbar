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
