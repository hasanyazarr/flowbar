import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \Session.endedAt) private var allSessions: [Session]
    @State private var period: AnalyticsPeriod = .week
    @State private var hoveredBucketID: Date?

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

    private var hoveredBucket: TrendBucket? {
        guard let id = hoveredBucketID else { return nil }
        return trend.first { $0.id == id }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Work trend").font(.headline)
                Spacer()
                // Hover edilen günün toplam süresi (ör. "6h 0m").
                if let bucket = hoveredBucket {
                    Text("\(bucket.label) · \(Duration.short(seconds: bucket.totalSeconds))")
                        .font(.caption).fontWeight(.semibold).monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity)
                }
            }
            Chart(trend) { bucket in
                BarMark(
                    x: .value("Period", bucket.label),
                    y: .value("Hours", Double(bucket.totalSeconds) / 3600.0)
                )
                .foregroundStyle(Color.accentColor.opacity(
                    hoveredBucketID == nil || hoveredBucketID == bucket.id ? 1.0 : 0.4
                ))
            }
            .frame(height: 160)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoveredBucketID = bucketID(at: location, proxy: proxy, geo: geo)
                            case .ended:
                                hoveredBucketID = nil
                            }
                        }
                }
            }
            .animation(.easeOut(duration: 0.12), value: hoveredBucketID)
        }
    }

    /// Fare konumundaki x değerinden (kategorik label) ilgili bucket'ın id'sini bulur.
    private func bucketID(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> Date? {
        let plotOrigin = geo[proxy.plotAreaFrame].origin
        let xInPlot = location.x - plotOrigin.x
        guard let label: String = proxy.value(atX: xInPlot) else { return nil }
        return trend.first { $0.label == label }?.id
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category breakdown").font(.headline)
            CategoryShareChart(categories: categories)
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
