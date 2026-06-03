import SwiftUI

/// Segmented bar showing how many projects are in each status (colors from
/// ProjectStatus.colorHex). Empty distribution renders a faint placeholder bar.
struct StatusDistributionBar: View {
    let distribution: [ProjectStatus: Int]

    private var total: Int { distribution.values.reduce(0, +) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                if total == 0 {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                } else {
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        let count = distribution[status] ?? 0
                        if count > 0 {
                            Rectangle()
                                .fill(Color(hex: status.colorHex) ?? .gray)
                                .frame(width: geo.size.width * CGFloat(count) / CGFloat(total))
                        }
                    }
                }
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }
}

/// Two thin bars comparing this-week vs last-week logged time for the folder.
/// Bars are scaled to the larger of the two; zero-zero renders faint.
struct WeeklyComparisonBar: View {
    let comparison: WeeklyComparison
    let colorHex: String

    private var maxSeconds: Int { max(comparison.thisWeekSeconds, comparison.lastWeekSeconds) }

    var body: some View {
        VStack(spacing: 3) {
            row(label: String(localized: "This week"), seconds: comparison.thisWeekSeconds, opacity: 1.0)
            row(label: String(localized: "Last week"), seconds: comparison.lastWeekSeconds, opacity: 0.45)
        }
    }

    private func row(label: String, seconds: Int, opacity: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            GeometryReader { geo in
                let fraction = maxSeconds == 0 ? 0 : CGFloat(seconds) / CGFloat(maxSeconds)
                Capsule()
                    .fill((Color(hex: colorHex) ?? .gray).opacity(maxSeconds == 0 ? 0.15 : opacity))
                    .frame(width: max(geo.size.width * fraction, maxSeconds == 0 ? geo.size.width : 2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 4)
            Text(Duration.short(seconds: seconds))
                .font(.system(size: 9)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

/// Single bar showing the folder's share of total logged time across all folders.
struct CategoryShareBar: View {
    let share: Double      // 0...1
    let colorHex: String

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(Color(hex: colorHex) ?? .gray)
                        .frame(width: geo.size.width * CGFloat(share))
                }
            }
            .frame(height: 4)
            Text("\(Int((share * 100).rounded()))%")
                .font(.system(size: 9)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}
