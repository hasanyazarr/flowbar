import SwiftUI

/// Manual 2-column grid of project history cards. The expanded project becomes
/// its own full-width row; closed ones pack 2-up in order. Single open at a time.
struct HistoryGridView: View {
    let folders: [ProjectHistoryFolder]

    // Session editing state is owned by HomeView (shared with the list view).
    let projects: [Project]
    let editingSessionID: UUID?
    let onEditSession: (Session) -> Void
    let onCancelEdit: () -> Void
    let onSaveEdit: () -> Void
    let onDeleteSession: (Session) -> Void

    @State private var expandedProjectID: UUID?

    private static let expandAnimation = Animation.snappy(duration: 0.2)

    private struct GridRow: Identifiable {
        let folders: [ProjectHistoryFolder]
        // İlk klasörün id'si kararlı kimlik verir; index tabanlı kimlik
        // expand/collapse'ta animasyonu yanlış karta uygulardı.
        var id: UUID { folders[0].id }
    }

    var body: some View {
        ScrollView {
            if folders.isEmpty {
                Text("No sessions saved yet")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        if row.folders.count == 1, let folder = row.folders.first, isExpanded(folder) {
                            card(for: folder)
                        } else {
                            HStack(spacing: 8) {
                                ForEach(row.folders) { folder in
                                    card(for: folder)
                                }
                                if row.folders.count == 1 {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .animation(Self.expandAnimation, value: expandedProjectID)
                .animation(Self.expandAnimation, value: editingSessionID)
            }
        }
    }

    private var rows: [GridRow] {
        var result: [GridRow] = []
        var pending: [ProjectHistoryFolder] = []
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

    private func isExpanded(_ folder: ProjectHistoryFolder) -> Bool {
        expandedProjectID == folder.id
    }

    private func card(for folder: ProjectHistoryFolder) -> some View {
        ProjectHistoryCard(
            folder: folder,
            isExpanded: isExpanded(folder),
            onToggle: {
                expandedProjectID = isExpanded(folder) ? nil : folder.id
            },
            projects: projects,
            editingSessionID: editingSessionID,
            onEditSession: onEditSession,
            onCancelEdit: onCancelEdit,
            onSaveEdit: onSaveEdit,
            onDeleteSession: onDeleteSession
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
