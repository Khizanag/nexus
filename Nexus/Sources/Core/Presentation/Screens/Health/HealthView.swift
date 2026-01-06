import SwiftUI
import SwiftData

struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var entries: [HealthEntryModel]

    @State private var showAddEntry = false
    @State private var selectedMetric: HealthMetricType?
    @State private var showHealthKitAuth = false

    // HealthKit data
    @State private var healthKitSteps: Double?
    @State private var healthKitCalories: Double?
    @State private var healthKitDistance: Double?
    @State private var healthKitHeartRate: Double?
    @State private var healthKitSleep: Double?
    @State private var healthKitWeight: Double?
    @State private var isLoadingHealthKit = false
    @State private var healthKitError: String?

    private let healthKitService = HealthKitService()
    private let metrics = HealthMetricType.allCases

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    healthKitBanner
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
            .task {
                await loadHealthKitData()
            }
            .refreshable {
                await loadHealthKitData()
            }
        }
    }

    @ViewBuilder
    private var healthKitBanner: some View {
        if healthKitService.isAvailable && !healthKitService.isAuthorized {
            NexusCard {
                HStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.nexusRed)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect HealthKit")
                            .font(.nexusHeadline)
                        Text("Sync your health data from Apple Health")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Connect") {
                        Task {
                            await requestHealthKitAuthorization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.nexusRed)
                }
            }
        }
    }

    private var todayOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if isLoadingHealthKit {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            HStack(spacing: 12) {
                TodayMetricCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: displaySteps,
                    color: .nexusGreen,
                    isFromHealthKit: healthKitSteps != nil
                )

                TodayMetricCard(
                    icon: "flame.fill",
                    title: "Calories",
                    value: displayCalories,
                    color: .nexusOrange,
                    isFromHealthKit: healthKitCalories != nil
                )

                TodayMetricCard(
                    icon: "moon.fill",
                    title: "Sleep",
                    value: displaySleep,
                    color: .indigo,
                    isFromHealthKit: healthKitSleep != nil
                )
            }

            HStack(spacing: 12) {
                TodayMetricCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: displayHeartRate,
                    color: .nexusRed,
                    isFromHealthKit: healthKitHeartRate != nil
                )

                TodayMetricCard(
                    icon: "figure.walk.motion",
                    title: "Distance",
                    value: displayDistance,
                    color: .nexusBlue,
                    isFromHealthKit: healthKitDistance != nil
                )

                TodayMetricCard(
                    icon: "drop.fill",
                    title: "Water",
                    value: latestValue(for: .waterIntake).map { "\(Int($0)) ml" } ?? "--",
                    color: .nexusTeal,
                    isFromHealthKit: false
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
                    MetricCard(
                        metric: metric,
                        latestValue: combinedValue(for: metric),
                        isFromHealthKit: isHealthKitValue(for: metric)
                    )
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

    private func combinedValue(for type: HealthMetricType) -> Double? {
        switch type {
        case .steps:
            return healthKitSteps ?? latestValue(for: type)
        case .calories:
            return healthKitCalories ?? latestValue(for: type)
        case .sleep:
            return healthKitSleep ?? latestValue(for: type)
        case .heartRate:
            return healthKitHeartRate ?? latestValue(for: type)
        case .weight:
            return healthKitWeight ?? latestValue(for: type)
        default:
            return latestValue(for: type)
        }
    }

    private func isHealthKitValue(for type: HealthMetricType) -> Bool {
        switch type {
        case .steps: return healthKitSteps != nil
        case .calories: return healthKitCalories != nil
        case .sleep: return healthKitSleep != nil
        case .heartRate: return healthKitHeartRate != nil
        case .weight: return healthKitWeight != nil
        default: return false
        }
    }
}

// MARK: - HealthKit Integration

private extension HealthView {
    var displaySteps: String {
        if let steps = healthKitSteps {
            return "\(Int(steps))"
        }
        return latestValue(for: .steps).map { "\(Int($0))" } ?? "--"
    }

    var displayCalories: String {
        if let calories = healthKitCalories {
            return "\(Int(calories))"
        }
        return latestValue(for: .calories).map { "\(Int($0))" } ?? "--"
    }

    var displaySleep: String {
        if let sleep = healthKitSleep {
            return String(format: "%.1fh", sleep)
        }
        return latestValue(for: .sleep).map { String(format: "%.1fh", $0) } ?? "--"
    }

    var displayHeartRate: String {
        if let heartRate = healthKitHeartRate {
            return "\(Int(heartRate)) bpm"
        }
        return latestValue(for: .heartRate).map { "\(Int($0)) bpm" } ?? "--"
    }

    var displayDistance: String {
        if let distance = healthKitDistance {
            return String(format: "%.1f km", distance)
        }
        return "--"
    }

    func loadHealthKitData() async {
        guard healthKitService.isAvailable else { return }

        isLoadingHealthKit = true
        defer { isLoadingHealthKit = false }

        if !healthKitService.isAuthorized {
            do {
                try await healthKitService.requestAuthorization()
            } catch {
                healthKitError = error.localizedDescription
                return
            }
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                if let steps = try? await healthKitService.fetchTodaySteps() {
                    await MainActor.run { healthKitSteps = steps }
                }
            }

            group.addTask {
                if let calories = try? await healthKitService.fetchTodayActiveEnergy() {
                    await MainActor.run { healthKitCalories = calories }
                }
            }

            group.addTask {
                if let distance = try? await healthKitService.fetchTodayDistance() {
                    await MainActor.run { healthKitDistance = distance }
                }
            }

            group.addTask {
                if let heartRate = try? await healthKitService.fetchLatestHeartRate() {
                    await MainActor.run { healthKitHeartRate = heartRate }
                }
            }

            group.addTask {
                if let sleep = try? await healthKitService.fetchTodaySleep() {
                    await MainActor.run { healthKitSleep = sleep }
                }
            }

            group.addTask {
                if let weight = try? await healthKitService.fetchLatestWeight() {
                    await MainActor.run { healthKitWeight = weight }
                }
            }
        }
    }

    func requestHealthKitAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
            await loadHealthKitData()
        } catch {
            healthKitError = error.localizedDescription
        }
    }
}

// MARK: - Today Metric Card

private struct TodayMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var isFromHealthKit: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                if isFromHealthKit {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.nexusRed)
                        .offset(x: 8, y: -4)
                }
            }

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
    var isFromHealthKit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(metricColor)

                    if isFromHealthKit {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.nexusRed)
                            .offset(x: 6, y: -4)
                    }
                }

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
    @Query(sort: \HealthEntryModel.date, order: .reverse)
    private var allEntries: [HealthEntryModel]

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
                        if chartData.count > 1 {
                            chartSection
                        }
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
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                QuickHealthEntryView(metric: metric)
            }
        }
    }

    private var periodSelector: some View {
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
                                Capsule()
                                    .fill(metricColor)
                            }
                        }
                        .foregroundStyle(selectedPeriod == period ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(Color.nexusSurface)
        }
    }

    private var emptyState: some View {
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

            Button {
                showAddEntry = true
            } label: {
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

    private var statisticsCard: some View {
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
                StatisticItem(
                    title: "Average",
                    value: formattedValue(statistics.average),
                    unit: metric.defaultUnit,
                    color: metricColor
                )

                Divider().frame(height: 40)

                StatisticItem(
                    title: "Min",
                    value: formattedValue(statistics.min),
                    unit: metric.defaultUnit,
                    color: .nexusBlue
                )

                Divider().frame(height: 40)

                StatisticItem(
                    title: "Max",
                    value: formattedValue(statistics.max),
                    unit: metric.defaultUnit,
                    color: .nexusGreen
                )

                Divider().frame(height: 40)

                StatisticItem(
                    title: "Entries",
                    value: "\(statistics.count)",
                    unit: "",
                    color: .secondary
                )
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

    private var chartSection: some View {
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

    private var entriesList: some View {
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

// MARK: - Supporting Types for MetricDetailView

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

private struct ChartDataPoint: Identifiable {
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

private struct SimpleBarChart: View {
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

// MARK: - Quick Health Entry View

private struct QuickHealthEntryView: View {
    let metric: HealthMetricType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var value: String = ""
    @State private var date: Date = .now
    @State private var notes: String = ""
    @FocusState private var isValueFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: metric.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(metricColor)
                            .frame(width: 40)

                        TextField("0", text: $value)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($isValueFocused)

                        Text(metric.defaultUnit)
                            .font(.nexusTitle2)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    DatePicker("Date & Time", selection: $date)
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle("Log \(metric.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(value.isEmpty)
                }
            }
            .onAppear {
                isValueFocused = true
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

    private func saveEntry() {
        guard let numericValue = Double(value) else { return }
        let entry = HealthEntryModel(
            type: metric,
            value: numericValue,
            unit: metric.defaultUnit,
            date: date,
            notes: notes
        )
        modelContext.insert(entry)
        dismiss()
    }
}

extension HealthMetricType: Identifiable {
    var id: String { rawValue }
}

#Preview {
    HealthView()
        .preferredColorScheme(.dark)
}
