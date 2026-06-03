import SwiftUI

/// Manual 2-column grid of category folder cards. The expanded folder (if any)
/// becomes its own full-width row; the remaining closed folders are packed into
/// 2-up rows, original order preserved. Single folder open at a time.
struct CategoryGridView: View {
    let folders: [CategoryFolder]

    @State private var expandedFolderID: CategoryFolderID?
    @State private var expandedProjectID: UUID?

    let onProjectDelete: (Project) -> Void

    /// Tek bir görüntü satırı: tek öğeli (genişlemiş ya da tek kalan kapalı kart)
    /// veya iki öğeli (kapalı çift). Kararlı `id`, satırın ilk klasörünün
    /// kimliğinden türetilir; böylece expand/collapse animasyonu doğru karta
    /// uygulanır (index tabanlı kimlik yanlış kartı oynatıyordu).
    private struct GridRow: Identifiable {
        let folders: [CategoryFolder]
        var id: CategoryFolderID { folders[0].id }
    }

    private static let expandAnimation = Animation.snappy(duration: 0.2)

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    if row.folders.count == 1, let folder = row.folders.first, isExpanded(folder) {
                        card(for: folder)            // full-width expanded row
                    } else {
                        HStack(spacing: 8) {
                            ForEach(row.folders) { folder in
                                card(for: folder)
                            }
                            if row.folders.count == 1 {
                                Color.clear.frame(maxWidth: .infinity) // keep last odd card half-width
                            }
                        }
                    }
                }
            }
        }
    }

    // Build display rows: expanded folder is its own row; others pack 2-up in order.
    private var rows: [GridRow] {
        var result: [GridRow] = []
        var pending: [CategoryFolder] = []
        func flushPending() {
            var idx = 0
            while idx < pending.count {
                result.append(GridRow(folders: Array(pending[idx..<min(idx + 2, pending.count)])))
                idx += 2
            }
            pending.removeAll()
        }
        for folder in folders {
            if isExpanded(folder) {
                flushPending()
                result.append(GridRow(folders: [folder]))
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
                withAnimation(Self.expandAnimation) {
                    expandedFolderID = isExpanded(folder) ? nil : folder.id
                    expandedProjectID = nil
                }
            },
            expandedProjectID: expandedProjectID,
            onProjectToggle: { id in
                withAnimation(Self.expandAnimation) {
                    expandedProjectID = (expandedProjectID == id) ? nil : id
                }
            },
            onProjectDelete: onProjectDelete
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
