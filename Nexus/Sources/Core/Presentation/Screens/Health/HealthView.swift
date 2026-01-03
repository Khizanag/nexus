import SwiftUI
import SwiftData

struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var entries: [HealthEntryModel]

    @State private var showAddEntry = false
    @State private var selectedMetric: HealthMetricType?

    private let metrics = HealthMetricType.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    todayOverview
                    metricsGrid
                    recentEntries
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Health")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                HealthEntryEditorView()
            }
            .sheet(item: $selectedMetric) { metric in
                MetricDetailView(metric: metric)
            }
        }
    }

    private var todayOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TodayMetricCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: latestValue(for: .steps).map { "\(Int($0))" } ?? "--",
                    color: .nexusGreen
                )

                TodayMetricCard(
                    icon: "drop.fill",
                    title: "Water",
                    value: latestValue(for: .waterIntake).map { "\(Int($0)) ml" } ?? "--",
                    color: .nexusBlue
                )

                TodayMetricCard(
                    icon: "moon.fill",
                    title: "Sleep",
                    value: latestValue(for: .sleep).map { String(format: "%.1fh", $0) } ?? "--",
                    color: .indigo
                )
            }
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(metrics, id: \.self) { metric in
                    MetricCard(metric: metric, latestValue: latestValue(for: metric))
                        .onTapGesture {
                            selectedMetric = metric
                        }
                }
            }
        }
    }

    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entries.prefix(10)) { entry in
                        HealthEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Health Data")
                .font(.nexusHeadline)

            Text("Start tracking your health metrics")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func latestValue(for type: HealthMetricType) -> Double? {
        entries
            .filter { $0.type == type && Calendar.current.isDateInToday($0.date) }
            .first?
            .value
    }
}

// MARK: - Today Metric Card

private struct TodayMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.nexusHeadline)

            Text(title)
                .font(.nexusCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let metric: HealthMetricType
    let latestValue: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metric.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(metricColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.displayName)
                    .font(.nexusSubheadline)

                if let value = latestValue {
                    Text("\(formattedValue(value)) \(metric.defaultUnit)")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No data")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    private var metricColor: Color {
        switch metric.color {
        case "purple": .nexusPurple
        case "blue": .nexusBlue
        case "indigo": .indigo
        case "green": .nexusGreen
        case "orange": .nexusOrange
        case "red": .nexusRed
        case "pink": .nexusPink
        case "yellow": .yellow
        case "teal": .nexusTeal
        default: .secondary
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Health Entry Row

private struct HealthEntryRow: View {
    let entry: HealthEntryModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.type.icon)
                .font(.system(size: 16))
                .foregroundStyle(metricColor)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(metricColor.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.type.displayName)
                    .font(.nexusSubheadline)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
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
    }

    private var metricColor: Color {
        switch entry.type.color {
        case "purple": .nexusPurple
        case "blue": .nexusBlue
        case "indigo": .indigo
        case "green": .nexusGreen
        case "orange": .nexusOrange
        case "red": .nexusRed
        case "pink": .nexusPink
        case "yellow": .yellow
        case "teal": .nexusTeal
        default: .secondary
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Metric Detail View

private struct MetricDetailView: View {
    let metric: HealthMetricType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [HealthEntryModel]

    init(metric: HealthMetricType) {
        self.metric = metric
        let metricRawValue = metric.rawValue
        _entries = Query(
            filter: #Predicate<HealthEntryModel> { $0.type.rawValue == metricRawValue },
            sort: \HealthEntryModel.date,
            order: .reverse
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        Text("\(formattedValue(entry.value)) \(entry.unit)")
                            .fontWeight(.medium)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle(metric.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

extension HealthMetricType: Identifiable {
    var id: String { rawValue }
}

#Preview {
    HealthView()
        .preferredColorScheme(.dark)
}
