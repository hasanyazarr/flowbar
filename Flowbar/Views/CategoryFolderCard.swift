import SwiftUI

struct CategoryFolderCard: View {
    let folder: CategoryFolder
    let share: Double
    let isExpanded: Bool
    let onToggle: () -> Void
    // Expanded-content plumbing for the inner project cards:
    let expandedProjectID: UUID?
    let onProjectToggle: (UUID) -> Void
    let onProjectDelete: (Project) -> Void

    private var summary: String {
        let time = Duration.short(seconds: folder.totalSeconds)
        return "\(folder.projectCount) " + String(localized: "projects") + " · " + time
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 8) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: folder.colorHex) ?? .gray)
                        .frame(width: 9, height: 9)
                    Text(folder.name)
                        .font(.callout).fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedBody
            } else {
                closedBody
            }
        }
        .padding(10)
        .background(CategorySurface.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isExpanded ? Color.accentColor.opacity(0.35) : CategorySurface.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var closedBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
            StatusDistributionBar(distribution: CategoryStats.statusDistribution(folder))
            WeeklyComparisonBar(comparison: CategoryStats.weeklyComparison(folder), colorHex: folder.colorHex)
            CategoryShareBar(share: share, colorHex: folder.colorHex)
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(folder.projects) { project in
                ProjectExpandableCard(
                    project: project,
                    isExpanded: expandedProjectID == project.id,
                    onToggle: { onProjectToggle(project.id) },
                    onDelete: { onProjectDelete(project) }
                )
            }
        }
    }
}
