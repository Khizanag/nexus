import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]

    @State private var selectedTab: AppTab = .home
    @State private var activeSheet: RootSheet?

    private let assistantLauncher = AssistantLauncher.shared
    private let taskLauncher = TaskLauncher.shared

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: AppTab.home) { HomeView() }
            Tab(AppTab.tasks.title, systemImage: AppTab.tasks.icon, value: AppTab.tasks) { TasksView() }
            Tab(AppTab.assistant.title, systemImage: AppTab.assistant.icon, value: AppTab.assistant) { AssistantView() }
            Tab(AppTab.health.title, systemImage: AppTab.health.icon, value: AppTab.health) { HealthView() }
            Tab(AppTab.finance.title, systemImage: AppTab.finance.icon, value: AppTab.finance) { FinanceView() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $activeSheet) { sheet in sheetContent(for: sheet) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { drainPendingActions() }
        }
        .onChange(of: assistantLauncher.shouldOpenAssistant) { _, shouldOpen in
            if shouldOpen {
                selectedTab = .assistant
                assistantLauncher.shouldOpenAssistant = false
            }
        }
        .onChange(of: assistantLauncher.pendingNavigation) { _, navigation in
            handle(navigation)
        }
        .onChange(of: taskLauncher.pendingTaskId) { _, taskId in
            if taskId != nil { drainPendingTask() }
        }
        .onAppear { drainPendingActions() }
    }
}

// MARK: - Sheets

private extension RootView {
    @ViewBuilder
    func sheetContent(for sheet: RootSheet) -> some View {
        switch sheet {
        case .waterLog: QuickWaterLogView()
        case .calendar: CalendarView()
        case .settings: SettingsView()
        case .task(let task): TaskEditorView(task: task)
        }
    }
}

// MARK: - Navigation

private extension RootView {
    func handle(_ navigation: AssistantNavigation?) {
        guard let navigation else { return }
        defer { assistantLauncher.pendingNavigation = nil }

        switch navigation {
        case .tab(let tab): selectedTab = tab
        case .calendar, .calendarEvent: activeSheet = .calendar
        case .note: selectedTab = .home
        case .task: selectedTab = .tasks
        case .subscription, .budget, .stock, .house: selectedTab = .finance
        case .settings: activeSheet = .settings
        }
    }
}

// MARK: - Pending Actions (widgets, intents, notifications)

private extension RootView {
    func drainPendingActions() {
        if let action = WidgetDataStore.consumePendingAction() {
            switch action {
            case .openAssistant: selectedTab = .assistant
            case .logWater: activeSheet = .waterLog
            }
        }
        drainPendingTask()
    }

    func drainPendingTask() {
        guard let (taskId, shouldMarkComplete) = taskLauncher.consumePendingTask() else { return }
        guard let task = allTasks.first(where: { $0.id == taskId }) else { return }

        if shouldMarkComplete {
            markComplete(task)
        } else {
            selectedTab = .tasks
            activeSheet = .task(task)
        }
    }

    func markComplete(_ task: TaskModel) {
        withAnimation(.spring(response: 0.5)) {
            task.isCompleted = true
            task.completedAt = .now
            task.updatedAt = .now
        }
        DefaultTaskNotificationService.shared.cancelReminder(for: task)
        selectedTab = .tasks
    }
}

// MARK: - Root Sheet

enum RootSheet: Identifiable {
    case waterLog
    case calendar
    case settings
    case task(TaskModel)

    var id: String {
        switch self {
        case .waterLog: "waterLog"
        case .calendar: "calendar"
        case .settings: "settings"
        case .task(let task): "task-\(task.id)"
        }
    }
}

// MARK: - Quick Water Log View

private struct QuickWaterLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 250

    private let presetAmounts = [150, 250, 500]

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                waterAmountCard
                presetButtons
                amountSlider
                Spacer()
                logButton
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(Color.nexusBackground)
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private extension QuickWaterLogView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    var waterAmountCard: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.lg, tint: .nexusTeal) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.nexusTeal)

                Text("\(Int(amount)) ml")
                    .font(.nexusDisplayNumber())
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water amount")
        .accessibilityValue("\(Int(amount)) milliliters")
    }

    var presetButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(presetAmounts, id: \.self) { milliliters in
                Button {
                    withAnimation(.spring(response: 0.3)) { amount = Double(milliliters) }
                } label: {
                    Text("\(milliliters)")
                        .font(.nexusHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.glass)
                .tint(amount == Double(milliliters) ? .nexusTeal : nil)
                .accessibilityLabel("\(milliliters) milliliters")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    var amountSlider: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Slider(value: $amount, in: 50...1000, step: 50) {
                Text("Amount")
            } minimumValueLabel: {
                Text("50").font(.nexusCaption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("1000").font(.nexusCaption).foregroundStyle(.secondary)
            }
            .tint(.nexusTeal)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    var logButton: some View {
        Button {
            logWater()
            dismiss()
        } label: {
            Label("Log Water", systemImage: "drop.fill")
                .font(.nexusHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.glassProminent)
        .tint(.nexusTeal)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    func logWater() {
        let entry = HealthEntryModel(
            type: .waterIntake,
            value: amount,
            unit: "ml",
            date: .now,
            notes: "Logged from Control Center"
        )
        modelContext.insert(entry)
    }
}

// MARK: - Preview

#Preview {
    RootView()
}
