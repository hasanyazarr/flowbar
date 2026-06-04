import SwiftUI

struct ProjectHistoryCard: View {
    let folder: ProjectHistoryFolder
    let isExpanded: Bool
    let onToggle: () -> Void
    // Session editing plumbing (shared with the list via HomeView state):
    let projects: [Project]
    let editingSessionID: UUID?
    let onEditSession: (Session) -> Void
    let onCancelEdit: () -> Void
    let onSaveEdit: () -> Void
    let onDeleteSession: (Session) -> Void

    private var summary: String {
        let time = Duration.short(seconds: folder.totalSeconds)
        return "\(folder.sessionCount) " + String(localized: "sessions") + " · " + time
    }

    private var dotColor: Color {
        guard let hex = folder.project.category?.colorHex,
              let color = Color(hex: hex) else { return .secondary }
        return color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 8) {
            VStack(alignment: .leading, spacing: 8) {
                header
                summaryLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if isExpanded {
                expandedSessions
            }
        }
        .padding(10)
        .background(CategorySurface.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isExpanded ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(dotColor).frame(width: 9, height: 9)
            Text(folder.project.name)
                .font(.callout).fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
    }

    private var summaryLine: some View {
        HStack(spacing: 8) {
            if let category = folder.project.category {
                CategoryChip(name: category.name, hex: category.colorHex)
            }
            Text(summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var expandedSessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(folder.sessions, id: \.id) { session in
                if editingSessionID == session.id {
                    SessionEditForm(
                        session: session,
                        projects: projects,
                        onCancel: onCancelEdit,
                        onSave: onSaveEdit
                    )
                } else {
                    SessionHistoryRow(
                        session: session,
                        onEdit: { onEditSession(session) },
                        onDelete: { onDeleteSession(session) }
                    )
                }
            }
        }
    }
}
