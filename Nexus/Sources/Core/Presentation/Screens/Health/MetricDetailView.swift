import SwiftUI
import SwiftData

struct MetricDetailView: View {
    let metric: HealthMetricType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var allEntries: [HealthEntryModel]

    @State private var showAddEntry = false
    @State private var selectedPeriod: MetricPeriod = .week

    private var entries: [HealthEntryModel] {
        allEntries.filter { $0.type == metric }
    }

    private var periodEntries: [HealthEntryModel] {
        let calendar = Calendar.current
        let now = Date()
        return entries.filter { entry in
            switch selectedPeriod {
            case .week:
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
                return entry.date >= weekAgo
            case .month:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var statistics: MetricStatistics {
        let values = periodEntries.map { $0.value }
        guard !values.isEmpty else {
            return MetricStatistics(average: 0, min: 0, max: 0, total: 0, count: 0)
        }
        return MetricStatistics(
            average: values.reduce(0, +) / Double(values.count),
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            total: values.reduce(0, +),
            count: values.count
        )
    }

    private var chartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: periodEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return grouped.map { date, entries in
            ChartDataPoint(date: date, value: entries.map { $0.value }.reduce(0, +) / Double(entries.count))
        }.sorted { $0.date < $1.date }.suffix(7).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodSelector
                    if entries.isEmpty {
                        emptyState
                    } else {
                        statisticsCard
                        if chartData.count > 1 { chartSection }
                        entriesList
                    }
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(metric.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAddEntry = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                QuickHealthEntryView(metric: metric)
            }
        }
    }
}

// MARK: - Period Selector

private extension MetricDetailView {
    var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(MetricPeriod.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.title)
                        .font(.nexusSubheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if selectedPeriod == period {
                                Capsule().fill(metricColor)
                            }
                        }
                        .foregroundStyle(selectedPeriod == period ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background { Capsule().fill(Color.nexusSurface) }
    }
}

// MARK: - Empty State

private extension MetricDetailView {
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: metric.icon)
                .font(.system(size: 48))
                .foregroundStyle(metricColor.opacity(0.5))

            VStack(spacing: 8) {
                Text("No \(metric.displayName) Data")
                    .font(.nexusHeadline)

                Text("Start tracking your \(metric.displayName.lowercased()) to see insights and trends")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button { showAddEntry = true } label: {
                Label("Add Entry", systemImage: "plus.circle.fill")
                    .font(.nexusHeadline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(metricColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Statistics Card

private extension MetricDetailView {
    var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(selectedPeriod.title)
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                StatisticItem(title: "Average", value: formattedValue(statistics.average), unit: metric.defaultUnit, color: metricColor)
                Divider().frame(height: 40)
                StatisticItem(title: "Min", value: formattedValue(statistics.min), unit: metric.defaultUnit, color: .nexusBlue)
                Divider().frame(height: 40)
                StatisticItem(title: "Max", value: formattedValue(statistics.max), unit: metric.defaultUnit, color: .nexusGreen)
                Divider().frame(height: 40)
                StatisticItem(title: "Entries", value: "\(statistics.count)", unit: "", color: .secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - Chart Section

private extension MetricDetailView {
    var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            SimpleBarChart(data: chartData, color: metricColor, unit: metric.defaultUnit)
                .frame(height: 150)
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                }
        }
    }
}

// MARK: - Entries List

private extension MetricDetailView {
    var entriesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(periodEntries.count) entries")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }

            LazyVStack(spacing: 8) {
                ForEach(periodEntries) { entry in
                    entryRow(entry)
                }
            }
        }
    }

    func entryRow(_ entry: HealthEntryModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.nexusSubheadline)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(formattedValue(entry.value)) \(entry.unit)")
                .font(.nexusHeadline)
                .foregroundStyle(metricColor)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Helpers

private extension MetricDetailView {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: metric.color)
    }

    func formattedValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

// MARK: - Supporting Types

private enum MetricPeriod: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct MetricStatistics {
    let average: Double
    let min: Double
    let max: Double
    let total: Double
    let count: Int
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct StatisticItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.nexusHeadline)
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.nexusCaption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SimpleBarChart: View {
    let data: [ChartDataPoint]
    let color: Color
    let unit: String

    private var maxValue: Double {
        data.map { $0.value }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { point in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: max(4, CGFloat(point.value / maxValue) * 100))

                    Text(point.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
