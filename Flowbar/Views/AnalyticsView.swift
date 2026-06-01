import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \Session.endedAt) private var allSessions: [Session]
    @State private var period: AnalyticsPeriod = .week

    private var sessions: [Session] {
        Analytics.filter(allSessions, period: period)
    }
    private var summary: AnalyticsSummary { Analytics.summary(sessions) }
    private var trend: [TrendBucket] { Analytics.trend(sessions, period: period) }
    private var categories: [CategoryTotal] { Analytics.categoryTotals(sessions) }
    private var topProjects: [ProjectTotal] { Analytics.projectTotals(sessions, limit: 5) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $period) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if sessions.isEmpty {
                Text("No sessions recorded in this period")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        kpiRow
                        trendSection
                        categorySection
                        projectSection
                    }
                }
                .hidesScrollIndicators()
            }
        }
    }

    private var kpiRow: some View {
        HStack(spacing: 10) {
            kpi(String(localized: "Total"), Duration.short(seconds: summary.totalSeconds))
            kpi(String(localized: "Sessions"), "\(summary.sessionCount)")
            kpi(String(localized: "Average"), Duration.short(seconds: summary.averageSeconds))
        }
    }

    private func kpi(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.semibold).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work trend").font(.headline)
            Chart(trend) { bucket in
                BarMark(
                    x: .value("Period", bucket.label),
                    y: .value("Hours", Double(bucket.totalSeconds) / 3600.0)
                )
                .foregroundStyle(Color.accentColor)
            }
            .frame(height: 160)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category breakdown").font(.headline)
            Chart(categories) { item in
                BarMark(
                    x: .value("Hours", Double(item.totalSeconds) / 3600.0),
                    y: .value("Category", item.name)
                )
                .foregroundStyle(Color(hex: item.colorHex) ?? .gray)
                .annotation(position: .trailing) {
                    Text(Duration.short(seconds: item.totalSeconds))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(categories.count) * 34 + 10)
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most worked projects").font(.headline)
            VStack(spacing: 6) {
                ForEach(topProjects) { project in
                    HStack {
                        Text(project.name).font(.callout).lineLimit(1)
                        Spacer(minLength: 10)
                        Text(Duration.short(seconds: project.totalSeconds))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
