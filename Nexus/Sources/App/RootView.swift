import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]

    @State private var selectedTab: Tab = .home
    @State private var previousTab: Tab = .home
    @State private var showAssistant = false
    @State private var pendingWaterLog = false
    @State private var showCalendar = false
    @State private var showSettings = false
    @State private var taskToShow: TaskModel?

    private var assistantLauncher = AssistantLauncher.shared
    private var taskLauncher = TaskLauncher.shared

    // MARK: - Body

    var body: some View {
        tabView
            .tint(.nexusPurple)
            .modifier(ChangeHandlersModifier(
                selectedTab: $selectedTab,
                previousTab: $previousTab,
                showAssistant: $showAssistant,
                assistantLauncher: assistantLauncher,
                taskLauncher: taskLauncher,
                scenePhase: scenePhase,
                handlePendingWidgetAction: handlePendingWidgetAction,
                handlePendingTaskAction: handlePendingTaskAction,
                handlePendingNavigation: handlePendingNavigation
            ))
            .modifier(SheetModifier(
                showAssistant: $showAssistant,
                pendingWaterLog: $pendingWaterLog,
                showCalendar: $showCalendar,
                showSettings: $showSettings,
                taskToShow: $taskToShow
            ))
    }
}

// MARK: - Tab View

private extension RootView {
    var tabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    func tabContent(for tab: Tab) -> some View {
        if tab.isContent {
            tab.view
        } else {
            Color.clear
        }
    }
}

// MARK: - Navigation Handlers

private extension RootView {
    func handlePendingNavigation() {
        guard let navigation = assistantLauncher.consumeNavigation() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigateTo(navigation)
        }
    }

    func navigateTo(_ navigation: AssistantNavigation) {
        switch navigation {
        case .tab(let tab):
            selectedTab = tab
        case .calendar, .calendarEvent:
            showCalendar = true
        case .note:
            selectedTab = .home
        case .task:
            selectedTab = .tasks
        case .subscription, .budget, .stock, .house:
            selectedTab = .finance
        case .settings:
            showSettings = true
        }
    }

    func handlePendingWidgetAction() {
        guard let action = WidgetDataStore.consumePendingAction() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch action {
            case .openAssistant:
                showAssistant = true
            case .logWater:
                pendingWaterLog = true
            }
        }
    }

    func handlePendingTaskAction() {
        guard let (taskId, shouldMarkComplete) = taskLauncher.consumePendingTask() else { return }
        guard let task = allTasks.first(where: { $0.id == taskId }) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if shouldMarkComplete {
                markTaskComplete(task)
            } else {
                openTask(task)
            }
        }
    }

    func markTaskComplete(_ task: TaskModel) {
        withAnimation(.spring(response: 0.5)) {
            task.isCompleted = true
            task.completedAt = .now
            task.updatedAt = .now
        }
        DefaultTaskNotificationService.shared.cancelReminder(for: task)
        selectedTab = .tasks
    }

    func openTask(_ task: TaskModel) {
        selectedTab = .tasks
        taskToShow = task
    }
}

// MARK: - Change Handlers Modifier

private struct ChangeHandlersModifier: ViewModifier {
    @Binding var selectedTab: Tab
    @Binding var previousTab: Tab
    @Binding var showAssistant: Bool
    let assistantLauncher: AssistantLauncher
    let taskLauncher: TaskLauncher
    let scenePhase: ScenePhase
    let handlePendingWidgetAction: () -> Void
    let handlePendingTaskAction: () -> Void
    let handlePendingNavigation: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == .assistant {
                    showAssistant = true
                    selectedTab = previousTab
                } else {
                    previousTab = newValue
                }
            }
            .onChange(of: assistantLauncher.shouldOpenAssistant) { _, shouldOpen in
                if shouldOpen {
                    showAssistant = true
                    assistantLauncher.shouldOpenAssistant = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    handlePendingWidgetAction()
                    handlePendingTaskAction()
                }
            }
            .onChange(of: showAssistant) { _, isShowing in
                if !isShowing {
                    handlePendingNavigation()
                }
            }
            .onChange(of: taskLauncher.pendingTaskId) { _, newTaskId in
                if newTaskId != nil {
                    handlePendingTaskAction()
                }
            }
    }
}

// MARK: - Sheet Modifier

private struct SheetModifier: ViewModifier {
    @Binding var showAssistant: Bool
    @Binding var pendingWaterLog: Bool
    @Binding var showCalendar: Bool
    @Binding var showSettings: Bool
    @Binding var taskToShow: TaskModel?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showAssistant) { AssistantView() }
            .sheet(isPresented: $pendingWaterLog) { QuickWaterLogView() }
            .sheet(isPresented: $showCalendar) { CalendarView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $taskToShow) { task in TaskEditorView(task: task) }
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
            VStack(spacing: 32) {
                Spacer()
                waterAmountCard
                presetButtons
                amountSlider
                Spacer()
                logButton
            }
            .background(Color.nexusBackground)
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }
}

// MARK: - Quick Water Log Toolbar

private extension QuickWaterLogView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }
}

// MARK: - Quick Water Log Subviews

private extension QuickWaterLogView {
    var waterAmountCard: some View {
        ConcentricCard(color: .nexusTeal) {
            VStack(spacing: 16) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                Text("\(Int(amount)) ml")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
    }

    var presetButtons: some View {
        HStack(spacing: 12) {
            ForEach(presetAmounts, id: \.self) { ml in
                presetButton(ml)
            }
        }
        .padding(.horizontal, 20)
    }

    func presetButton(_ ml: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                amount = Double(ml)
            }
        } label: {
            Text("\(ml)")
                .font(.nexusHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { presetButtonBackground(isSelected: amount == Double(ml)) }
                .foregroundStyle(amount == Double(ml) ? .white : .primary)
        }
    }

    @ViewBuilder
    func presetButtonBackground(isSelected: Bool) -> some View {
        if isSelected {
            ConcentricRectangleBackground(
                cornerRadius: 12,
                layers: 4,
                baseColor: .nexusTeal,
                spacing: 3
            )
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    var amountSlider: some View {
        VStack(spacing: 8) {
            Slider(value: $amount, in: 50...1000, step: 50)
                .tint(Color.nexusTeal)

            HStack {
                Text("50 ml")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1000 ml")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 32)
    }

    var logButton: some View {
        ConcentricButton("Log Water", icon: "drop.fill", color: .nexusTeal) {
            logWater()
            dismiss()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Quick Water Log Actions

private extension QuickWaterLogView {
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
        .preferredColorScheme(.dark)
}
