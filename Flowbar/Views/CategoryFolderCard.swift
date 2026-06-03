import SwiftUI

struct CategoryFolderCard: View {
    let folder: CategoryFolder
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
            // Başlık + özet her zaman var ve tek bir tıklanabilir bölge.
            // Sabit yapı + tek onTapGesture: aç/kapa için tap hedefi her
            // durumda aynı yerde olduğundan tıklama güvenilir tetiklenir,
            // aynı noktaya tekrar tıklamak kartı kapatır.
            VStack(alignment: .leading, spacing: 8) {
                header
                summaryText
                if !isExpanded {
                    StatusDistributionLabels(distribution: CategoryStats.statusDistribution(folder))
                    WeeklyComparisonPills(comparison: CategoryStats.weeklyComparison(folder))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            // Açık içerikteki proje kartları kendi tıklamalarını alır;
            // bu bölge toggle gesture'ının dışında kalır.
            if isExpanded {
                expandedProjects
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

    private var summaryText: some View {
        Text(summary)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var expandedProjects: some View {
        VStack(alignment: .leading, spacing: 6) {
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

