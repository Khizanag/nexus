import SwiftUI
import SwiftData

struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var entries: [HealthEntryModel]

    @State private var showAddEntry = false
    @State private var selectedMetric: HealthMetricType?
    @State private var showHealthKitAuth = false

    @State private var healthKitSteps: Double?
    @State private var healthKitCalories: Double?
    @State private var healthKitDistance: Double?
    @State private var healthKitHeartRate: Double?
    @State private var healthKitSleep: Double?
    @State private var healthKitWeight: Double?
    @State private var isLoadingHealthKit = false
    @State private var healthKitError: String?

    private let healthKitService = DefaultHealthKitService()
    private let metrics = HealthMetricType.allCases

    // MARK: - Body

    var body: some View {
        NavigationStack {
            scrollContent
                .background(Color.nexusBackground)
                .navigationTitle("Health")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showAddEntry) { HealthEntryEditorView() }
                .sheet(item: $selectedMetric) { metric in MetricDetailView(metric: metric) }
                .task { await loadHealthKitData() }
                .refreshable { await loadHealthKitData() }
        }
    }
}

// MARK: - Toolbar

private extension HealthView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddEntry = true } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Main Content

private extension HealthView {
    var scrollContent: some View {
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
    }
}

// MARK: - HealthKit Banner

private extension HealthView {
    @ViewBuilder
    var healthKitBanner: some View {
        if healthKitService.isAvailable, !healthKitService.isAuthorized {
            NexusCard {
                bannerContent
            }
        }
    }

    var bannerContent: some View {
        HStack(spacing: 12) {
            bannerIcon
            bannerText
            Spacer()
            connectButton
        }
    }

    var bannerIcon: some View {
        Image(systemName: "heart.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(Color.nexusRed)
    }

    var bannerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Connect HealthKit")
                .font(.nexusHeadline)
            Text("Sync your health data from Apple Health")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var connectButton: some View {
        Button("Connect") {
            Task { await requestHealthKitAuthorization() }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.nexusRed)
    }
}

// MARK: - Today Overview

private extension HealthView {
    var todayOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            todayHeader
            todayTopRow
            todayBottomRow
        }
    }

    var todayHeader: some View {
        HStack {
            Text("Today")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)
            Spacer()
            if isLoadingHealthKit {
                ProgressView().scaleEffect(0.8)
            }
        }
    }

    var todayTopRow: some View {
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
    }

    var todayBottomRow: some View {
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

// MARK: - Metrics Grid

private extension HealthView {
    var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            metricsGridContent
        }
    }

    var metricsGridContent: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(metrics, id: \.self) { metric in
                MetricCard(
                    metric: metric,
                    latestValue: combinedValue(for: metric),
                    isFromHealthKit: isHealthKitValue(for: metric)
                )
                .onTapGesture { selectedMetric = metric }
            }
        }
    }
}

// MARK: - Recent Entries

private extension HealthView {
    var recentEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
    }

    var entriesList: some View {
        LazyVStack(spacing: 8) {
            ForEach(entries.prefix(10)) { entry in
                HealthEntryRow(entry: entry)
            }
        }
    }

    var emptyState: some View {
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
}

// MARK: - Display Values

private extension HealthView {
    var displaySteps: String {
        if let steps = healthKitSteps { return "\(Int(steps))" }
        return latestValue(for: .steps).map { "\(Int($0))" } ?? "--"
    }

    var displayCalories: String {
        if let calories = healthKitCalories { return "\(Int(calories))" }
        return latestValue(for: .calories).map { "\(Int($0))" } ?? "--"
    }

    var displaySleep: String {
        if let sleep = healthKitSleep { return String(format: "%.1fh", sleep) }
        return latestValue(for: .sleep).map { String(format: "%.1fh", $0) } ?? "--"
    }

    var displayHeartRate: String {
        if let heartRate = healthKitHeartRate { return "\(Int(heartRate)) bpm" }
        return latestValue(for: .heartRate).map { "\(Int($0)) bpm" } ?? "--"
    }

    var displayDistance: String {
        if let distance = healthKitDistance { return String(format: "%.1f km", distance) }
        return "--"
    }
}

// MARK: - Data Helpers

private extension HealthView {
    func latestValue(for type: HealthMetricType) -> Double? {
        entries.filter { $0.type == type && Calendar.current.isDateInToday($0.date) }.first?.value
    }

    func combinedValue(for type: HealthMetricType) -> Double? {
        switch type {
        case .steps: return healthKitSteps ?? latestValue(for: type)
        case .calories: return healthKitCalories ?? latestValue(for: type)
        case .sleep: return healthKitSleep ?? latestValue(for: type)
        case .heartRate: return healthKitHeartRate ?? latestValue(for: type)
        case .weight: return healthKitWeight ?? latestValue(for: type)
        default: return latestValue(for: type)
        }
    }

    func isHealthKitValue(for type: HealthMetricType) -> Bool {
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
            group.addTask { await fetchSteps() }
            group.addTask { await fetchCalories() }
            group.addTask { await fetchDistance() }
            group.addTask { await fetchHeartRate() }
            group.addTask { await fetchSleep() }
            group.addTask { await fetchWeight() }
        }
    }

    func fetchSteps() async {
        if let steps = try? await healthKitService.fetchTodaySteps() {
            await MainActor.run { healthKitSteps = steps }
        }
    }

    func fetchCalories() async {
        if let calories = try? await healthKitService.fetchTodayActiveEnergy() {
            await MainActor.run { healthKitCalories = calories }
        }
    }

    func fetchDistance() async {
        if let distance = try? await healthKitService.fetchTodayDistance() {
            await MainActor.run { healthKitDistance = distance }
        }
    }

    func fetchHeartRate() async {
        if let heartRate = try? await healthKitService.fetchLatestHeartRate() {
            await MainActor.run { healthKitHeartRate = heartRate }
        }
    }

    func fetchSleep() async {
        if let sleep = try? await healthKitService.fetchTodaySleep() {
            await MainActor.run { healthKitSleep = sleep }
        }
    }

    func fetchWeight() async {
        if let weight = try? await healthKitService.fetchLatestWeight() {
            await MainActor.run { healthKitWeight = weight }
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

// MARK: - HealthMetricType Extension

extension HealthMetricType: Identifiable {
    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    HealthView()
        .preferredColorScheme(.dark)
}
