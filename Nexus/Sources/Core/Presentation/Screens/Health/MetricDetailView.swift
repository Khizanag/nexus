import SwiftUI
import SwiftData
import Charts

struct MetricDetailView: View {
    let metric: HealthMetricType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var allEntries: [HealthEntryModel]

    @State private var showAddEntry = false
    @State private var selectedPeriod: MetricPeriod = .week
    @State private var chartSelection: Date?

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
        return grouped.map { date, dayEntries in
            ChartDataPoint(date: date, value: dayEntries.map { $0.value }.reduce(0, +) / Double(dayEntries.count))
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    periodSelector
                    if entries.isEmpty {
                        emptyState
                    } else {
                        statisticsCard
                        if chartData.count > 1 { chartSection }
                        entriesList
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color.nexusBackground)
            .navigationTitle(metric.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAddEntry = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add entry")
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
        Picker("Period", selection: $selectedPeriod) {
            ForEach(MetricPeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Time period")
    }
}

// MARK: - Empty State

private extension MetricDetailView {
    var emptyState: some View {
        ContentUnavailableView {
            Label("No \(metric.displayName) Data", systemImage: metric.icon)
        } description: {
            Text("Start tracking your \(metric.displayName.lowercased()) to see insights and trends")
        } actions: {
            Button {
                showAddEntry = true
            } label: {
                Label("Add Entry", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.glassProminent)
            .tint(metricColor)
        }
    }
}

// MARK: - Statistics Card

private extension MetricDetailView {
    var statisticsCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
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
        .padding(DesignSystem.Spacing.md)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
    }
}

// MARK: - Chart Section

private extension MetricDetailView {
    var chartSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Trend")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            trendChart
                .padding(DesignSystem.Spacing.md)
                .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        }
    }

    var trendChart: some View {
        Chart {
            ForEach(chartData) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value(metric.defaultUnit, point.value)
                )
                .foregroundStyle(metricColor.gradient)
                .cornerRadius(DesignSystem.CornerRadius.sm / 2)
            }

            RuleMark(y: .value("Average", statistics.average))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(metricColor.opacity(0.6))
                .annotation(position: .trailing, alignment: .leading) {
                    Text("avg")
                        .font(.nexusCaption2)
                        .foregroundStyle(metricColor.opacity(0.8))
                }

            if let selection = chartSelection,
               let selected = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selection) }) {
                RuleMark(x: .value("Selected", selected.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(formattedValue(selected.value)) \(metric.defaultUnit)")
                            .font(.nexusCaption)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, DesignSystem.Spacing.xxs)
                            .glassBackground(in: Capsule())
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.nexusCaption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formattedValue(v))
                            .font(.nexusCaption2)
                    }
                }
            }
        }
        .chartScrollableAxes(chartData.count > 7 ? .horizontal : [])
        .chartXSelection(value: $chartSelection)
        .frame(height: 160)
        .accessibilityLabel("\(metric.displayName) trend chart, \(chartData.count) data points")
    }
}

// MARK: - Entries List

private extension MetricDetailView {
    var entriesList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("History")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(periodEntries.count) entries")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }

            if periodEntries.isEmpty {
                ContentUnavailableView(
                    "No entries for this period",
                    systemImage: metric.icon
                )
            } else {
                List {
                    ForEach(periodEntries) { entry in
                        entryRow(entry)
                            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xxs, leading: 0, bottom: DesignSystem.Spacing.xxs, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(periodEntries.count) * 68)
            }
        }
    }

    func entryRow(_ entry: HealthEntryModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
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
        .padding(DesignSystem.Spacing.sm)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.date.formatted(date: .abbreviated, time: .shortened)), \(formattedValue(entry.value)) \(entry.unit)")
    }
}

// MARK: - Helpers

private extension MetricDetailView {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: metric.color)
    }

    func formattedValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
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
        VStack(spacing: DesignSystem.Spacing.xxs) {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(unit.isEmpty ? value : "\(value) \(unit)")
    }
}
