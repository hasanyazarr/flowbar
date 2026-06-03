import Foundation

/// Stable identity for a folder in the grid. Real categories use their UUID;
/// the uncategorized bucket uses a fixed sentinel so it can be tracked
/// (selected/expanded) like any other folder.
enum CategoryFolderID: Hashable {
    case category(UUID)
    case uncategorized
}

/// One category "folder": a category (or the uncategorized bucket) plus its
/// active projects and derived totals.
struct CategoryFolder: Identifiable {
    let id: CategoryFolderID
    let name: String
    let colorHex: String
    let projects: [Project]
    /// Toplam loglanan süre, kuruluş anında bir kez hesaplanır (her SwiftUI
    /// render'ında sessions üzerinde yeniden iterasyon yapılmasın diye).
    let totalSeconds: Int

    var projectCount: Int { projects.count }
}

struct WeeklyComparison {
    let thisWeekSeconds: Int
    let lastWeekSeconds: Int
}

enum CategoryStats {
    /// Logged seconds for the folder this week vs last week, by session endedAt.
    static func weeklyComparison(_ folder: CategoryFolder, now: Date = .now,
                                 calendar: Calendar = .current) -> WeeklyComparison {
        let lastWeekRef = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        var thisWeek = 0
        var lastWeek = 0
        for project in folder.projects {
            for session in project.sessions {
                if calendar.isDate(session.endedAt, equalTo: now, toGranularity: .weekOfYear) {
                    thisWeek += session.loggedSeconds
                } else if calendar.isDate(session.endedAt, equalTo: lastWeekRef, toGranularity: .weekOfYear) {
                    lastWeek += session.loggedSeconds
                }
            }
        }
        return WeeklyComparison(thisWeekSeconds: thisWeek, lastWeekSeconds: lastWeek)
    }

    /// Folder's fraction (0...1) of total logged time across all folders.
    /// Returns 0 when there is no logged time anywhere.
    static func share(_ folder: CategoryFolder, among folders: [CategoryFolder]) -> Double {
        let grandTotal = folders.reduce(0) { $0 + $1.totalSeconds }
        guard grandTotal > 0 else { return 0 }
        return Double(folder.totalSeconds) / Double(grandTotal)
    }

    /// Number of projects in the folder per status. Statuses with zero projects
    /// are omitted from the dictionary.
    static func statusDistribution(_ folder: CategoryFolder) -> [ProjectStatus: Int] {
        var counts: [ProjectStatus: Int] = [:]
        for project in folder.projects {
            counts[project.status, default: 0] += 1
        }
        return counts
    }

    /// Groups projects into folders: one per distinct category (by category id),
    /// plus a trailing uncategorized folder for projects without a category.
    /// Category folders are sorted by name; uncategorized always last.
    static func folders(projects: [Project]) -> [CategoryFolder] {
        var categoryBuckets: [UUID: (category: Category, projects: [Project])] = [:]
        var uncategorized: [Project] = []

        for project in projects {
            if let category = project.category {
                categoryBuckets[category.id, default: (category, [])].projects.append(project)
            } else {
                uncategorized.append(project)
            }
        }

        var result = categoryBuckets.values
            .map { bucket in
                CategoryFolder(
                    id: .category(bucket.category.id),
                    name: bucket.category.name,
                    colorHex: bucket.category.colorHex,
                    projects: bucket.projects,
                    totalSeconds: bucket.projects.reduce(0) { $0 + $1.totalLoggedSeconds }
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if !uncategorized.isEmpty {
            result.append(CategoryFolder(
                id: .uncategorized,
                name: Analytics.uncategorizedName,
                colorHex: Analytics.uncategorizedHex,
                projects: uncategorized,
                totalSeconds: uncategorized.reduce(0) { $0 + $1.totalLoggedSeconds }
            ))
        }
        return result
    }
}
