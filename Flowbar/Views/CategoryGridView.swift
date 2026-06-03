import SwiftUI

/// Manual 2-column grid of category folder cards. The expanded folder (if any)
/// becomes its own full-width row; the remaining closed folders are packed into
/// 2-up rows, original order preserved. Single folder open at a time.
struct CategoryGridView: View {
    let folders: [CategoryFolder]

    @State private var expandedFolderID: CategoryFolderID?
    @State private var expandedProjectID: UUID?

    let onProjectDelete: (Project) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(rows.indices, id: \.self) { i in
                    let row = rows[i]
                    if row.count == 1, let folder = row.first, isExpanded(folder) {
                        card(for: folder)            // full-width expanded row
                    } else {
                        HStack(spacing: 8) {
                            ForEach(row) { folder in
                                card(for: folder)
                            }
                            if row.count == 1 {
                                Color.clear.frame(maxWidth: .infinity) // keep last odd card half-width
                            }
                        }
                    }
                }
            }
        }
    }

    // Build display rows: expanded folder is its own row; others pack 2-up in order.
    private var rows: [[CategoryFolder]] {
        var result: [[CategoryFolder]] = []
        var pending: [CategoryFolder] = []
        func flushPending() {
            var idx = 0
            while idx < pending.count {
                result.append(Array(pending[idx..<min(idx + 2, pending.count)]))
                idx += 2
            }
            pending.removeAll()
        }
        for folder in folders {
            if isExpanded(folder) {
                flushPending()
                result.append([folder])
            } else {
                pending.append(folder)
            }
        }
        flushPending()
        return result
    }

    private func isExpanded(_ folder: CategoryFolder) -> Bool {
        expandedFolderID == folder.id
    }

    private func card(for folder: CategoryFolder) -> some View {
        CategoryFolderCard(
            folder: folder,
            share: CategoryStats.share(folder, among: folders),
            isExpanded: isExpanded(folder),
            onToggle: {
                withAnimation(.snappy(duration: 0.2)) {
                    expandedFolderID = isExpanded(folder) ? nil : folder.id
                    expandedProjectID = nil
                }
            },
            expandedProjectID: expandedProjectID,
            onProjectToggle: { id in
                withAnimation(.snappy(duration: 0.18)) {
                    expandedProjectID = (expandedProjectID == id) ? nil : id
                }
            },
            onProjectDelete: onProjectDelete
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
