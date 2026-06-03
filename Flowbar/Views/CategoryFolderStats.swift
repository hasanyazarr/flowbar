import SwiftUI

/// Kategori kartında durumların nokta + sayı olarak özeti
/// ("● 5 devam · ● 1 bitti …"). Yatay yığılmış çubuk yerine okunabilir
/// etiketler kullanır; sadece projesi olan durumlar gösterilir.
struct StatusDistributionLabels: View {
    let distribution: [ProjectStatus: Int]

    private var entries: [(status: ProjectStatus, count: Int)] {
        ProjectStatus.allCases.compactMap { status in
            let count = distribution[status] ?? 0
            return count > 0 ? (status, count) : nil
        }
    }

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            FlowLayout(spacing: 4) {
                ForEach(entries, id: \.status) { entry in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: entry.status.colorHex) ?? .gray)
                            .frame(width: 6, height: 6)
                        Text("\(entry.count) \(entry.status.label)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

/// "Bu hafta" / "Geçen hafta" toplam sürelerini iki küçük pill olarak gösterir.
/// Çubuk yok; etiket + süre metni.
struct WeeklyComparisonPills: View {
    let comparison: WeeklyComparison

    var body: some View {
        HStack(spacing: 6) {
            pill(label: String(localized: "This week"), seconds: comparison.thisWeekSeconds, prominent: true)
            pill(label: String(localized: "Last week"), seconds: comparison.lastWeekSeconds, prominent: false)
        }
    }

    private func pill(label: String, seconds: Int, prominent: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(Duration.short(seconds: seconds))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(prominent ? .primary : .secondary)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(prominent ? 0.12 : 0.07))
        .clipShape(Capsule())
    }
}
