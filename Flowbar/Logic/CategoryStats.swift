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

    var projectCount: Int { projects.count }
    var totalSeconds: Int { projects.reduce(0) { $0 + $1.totalLoggedSeconds } }
}

enum CategoryStats {
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
                    projects: bucket.projects
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if !uncategorized.isEmpty {
            result.append(CategoryFolder(
                id: .uncategorized,
                name: Analytics.uncategorizedName,
                colorHex: Analytics.uncategorizedHex,
                projects: uncategorized
            ))
        }
        return result
    }
}
