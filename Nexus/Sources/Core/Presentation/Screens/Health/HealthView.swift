import SwiftUI
import SwiftData

struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var entries: [HealthEntryModel]
    @Query(sort: \NutritionEntryModel.date, order: .reverse) private var nutritionEntries: [NutritionEntryModel]

    @AppStorage("dailyCalorieGoal") private var calorieGoal = 2000

    @State private var showAddEntry = false
    @State private var selectedMetric: HealthMetricType?
    @State private var showNutritionHub = false

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
                .fullScreenCover(isPresented: $showNutritionHub) { NutritionHubView() }
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
            VStack(spacing: DesignSystem.Spacing.lg) {
                healthKitBanner
                todayOverview
                nutritionHubCard
                metricsGrid
                recentEntries
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 120)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    var nutritionHubCard: some View {
        Button { showNutritionHub = true } label: {
            GlassCard(tint: .nexusOrange) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "fork.knife")
                        .font(.nexusTitle2)
                        .foregroundStyle(Color.nexusOrange)
                        .frame(width: 44, height: 44)
                        .background(
                            Color.nexusOrange.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("Nutrition")
                            .font(.nexusHeadline)
                            .foregroundStyle(Color.nexusTextPrimary)

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("\(Int(todayNutritionCalories)) / \(calorieGoal) kcal")
                                .font(.nexusCaption)
                                .foregroundStyle(Color.nexusTextSecondary)

                            ProgressBar(progress: nutritionProgress, color: .nexusOrange, height: 4)
                                .frame(width: 60)
                                .accessibilityHidden(true)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Nutrition")
        .accessibilityValue("\(Int(todayNutritionCalories)) of \(calorieGoal) kilocalories")
    }

    private var todayNutritionCalories: Double {
        nutritionEntries
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }

    private var nutritionProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return todayNutritionCalories / Double(calorieGoal)
    }
}

// MARK: - HealthKit Banner

private extension HealthView {
    @ViewBuilder
    var healthKitBanner: some View {
        if healthKitService.isAvailable, !healthKitService.isAuthorized {
            GlassCard {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "heart.circle.fill")
                        .font(.nexusTitle)
                        .foregroundStyle(Color.nexusRed)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("Connect HealthKit")
                            .font(.nexusHeadline)
                        Text("Sync your health data from Apple Health")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Connect") {
                        Task { await requestHealthKitAuthorization() }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.nexusRed)
                    .accessibilityLabel("Connect HealthKit")
                }
            }
        }
    }
}

// MARK: - Today Overview

private extension HealthView {
    var todayOverview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
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
        HStack(spacing: DesignSystem.Spacing.sm) {
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
        HStack(spacing: DesignSystem.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Track")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            metricsGridContent
        }
    }

    var metricsGridContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignSystem.Spacing.sm),
                GridItem(.flexible(), spacing: DesignSystem.Spacing.sm),
            ],
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(metrics, id: \.self) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    MetricCard(
                        metric: metric,
                        latestValue: combinedValue(for: metric),
                        isFromHealthKit: isHealthKitValue(for: metric)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(metric.displayName)
                .accessibilityValue(
                    combinedValue(for: metric)
                        .map { "\(formattedMetricValue($0)) \(metric.defaultUnit)" } ?? "No data"
                )
                .accessibilityHint("Open \(metric.displayName) details")
            }
        }
    }
}

// MARK: - Recent Entries

private extension HealthView {
    var recentEntries: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Recent Entries")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                ContentUnavailableView(
                    "No Health Data",
                    systemImage: "heart.text.square",
                    description: Text("Start tracking your health metrics")
                )
            } else {
                List {
                    ForEach(entries.prefix(10)) { entry in
                        HealthEntryRow(entry: entry)
                            .listRowInsets(EdgeInsets(
                                top: DesignSystem.Spacing.xxs,
                                leading: 0,
                                bottom: DesignSystem.Spacing.xxs,
                                trailing: 0
                            ))
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
                .frame(height: CGFloat(min(entries.count, 10)) * 72)
            }
        }
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

    func formattedMetricValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
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

        async let steps = try? healthKitService.fetchTodaySteps()
        async let calories = try? healthKitService.fetchTodayActiveEnergy()
        async let distance = try? healthKitService.fetchTodayDistance()
        async let heartRate = try? healthKitService.fetchLatestHeartRate()
        async let sleep = try? healthKitService.fetchTodaySleep()
        async let weight = try? healthKitService.fetchLatestWeight()

        healthKitSteps = await steps
        healthKitCalories = await calories
        healthKitDistance = await distance
        healthKitHeartRate = await heartRate
        healthKitSleep = await sleep
        healthKitWeight = await weight
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
}
