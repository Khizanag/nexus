import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var widgetManager = HomeWidgetManager.shared

    @Query(sort: \NoteModel.updatedAt, order: .reverse)
    private var recentNotes: [NoteModel]

    @Query(filter: #Predicate<TaskModel> { !$0.isCompleted }, sort: \TaskModel.dueDate)
    private var upcomingTasks: [TaskModel]

    @Query(filter: #Predicate<TaskModel> { $0.isCompleted }, sort: \TaskModel.completedAt, order: .reverse)
    private var completedTasks: [TaskModel]

    @State private var greeting: String = ""
    @State private var showSettings = false
    @State private var showNewNote = false
    @State private var showNewTask = false
    @State private var showNewTransaction = false
    @State private var showHealthEntry = false
    @State private var showInsights = false
    @State private var showWidgetEditor = false
    @State private var selectedNote: NoteModel?
    @State private var selectedTask: TaskModel?

    @State private var showSubscriptions = false
    @State private var showBudgets = false
    @State private var showHealth = false
    @State private var showHouse = false
    @State private var showNotes = false
    @State private var showTasks = false
    @State private var showCalendar = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            scrollContent
                .background(Color.nexusBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .modifier(SheetModifier(
            showSettings: $showSettings,
            showNewNote: $showNewNote,
            showNewTask: $showNewTask,
            showNewTransaction: $showNewTransaction,
            showHealthEntry: $showHealthEntry,
            showInsights: $showInsights,
            showWidgetEditor: $showWidgetEditor,
            selectedNote: $selectedNote,
            selectedTask: $selectedTask,
            showSubscriptions: $showSubscriptions,
            showBudgets: $showBudgets,
            showHouse: $showHouse,
            showNotes: $showNotes,
            showTasks: $showTasks,
            showCalendar: $showCalendar
        ))
        .onAppear { updateGreeting() }
    }
}

// MARK: - Toolbar

private extension HomeView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Main Content

private extension HomeView {
    var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.bottom, 24)

                if !widgetManager.selectedWidgets.isEmpty {
                    SectionDivider()
                    widgetsSection
                        .padding(.vertical, 20)
                }

                SectionDivider()
                quickActionsSection
                    .padding(.vertical, 20)

                SectionDivider()
                insightsSection
                    .padding(.vertical, 20)

                SectionDivider()
                recentActivitySection
                    .padding(.vertical, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Header Section

private extension HomeView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.nexusTitle2)
                .foregroundStyle(.secondary)

            Text("Your Day at a Glance")
                .font(.nexusLargeTitle)
                .foregroundStyle(.primary)
        }
        .padding(.top, 16)
    }
}

// MARK: - Widgets Section

private extension HomeView {
    var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetsSectionHeader
            widgetsGrid
        }
    }

    var widgetsSectionHeader: some View {
        HStack {
            Text("Widgets")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button { showWidgetEditor = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                    Text("Edit")
                }
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusPurple)
            }
        }
    }

    var widgetsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(widgetManager.selectedWidgets) { widget in
                HomeWidgetCard(widget: widget) {
                    handleWidgetTap(widget)
                }
            }
        }
    }
}

// MARK: - Quick Actions Section

private extension HomeView {
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            quickActionsRow
        }
    }

    var quickActionsRow: some View {
        HStack(spacing: 12) {
            QuickActionCard(
                title: "New Note",
                icon: "square.and.pencil",
                color: .notesColor
            ) {
                showNewNote = true
            }

            QuickActionCard(
                title: "Add Task",
                icon: "plus.circle",
                color: .tasksColor
            ) {
                showNewTask = true
            }

            QuickActionCard(
                title: "Log Expense",
                icon: "creditcard",
                color: .financeColor
            ) {
                showNewTransaction = true
            }

            QuickActionCard(
                title: "Track Health",
                icon: "heart",
                color: .healthColor
            ) {
                showHealthEntry = true
            }
        }
    }
}

// MARK: - Insights Section

private extension HomeView {
    var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            insightsSectionHeader
            insightsCard
        }
    }

    var insightsSectionHeader: some View {
        HStack {
            Text("Today's Insights")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button("View All") { showInsights = true }
                .font(.nexusSubheadline)
                .foregroundStyle(Color.nexusPurple)
        }
    }

    var insightsCard: some View {
        NexusGlassCard {
            HStack(spacing: 16) {
                InsightItem(
                    title: "Tasks",
                    value: "\(upcomingTasks.count)",
                    subtitle: "pending",
                    color: .tasksColor
                )

                Divider()
                    .frame(height: 40)

                InsightItem(
                    title: "Notes",
                    value: "\(recentNotes.count)",
                    subtitle: "total",
                    color: .notesColor
                )

                Divider()
                    .frame(height: 40)

                InsightItem(
                    title: "Done Today",
                    value: "\(tasksCompletedToday)",
                    subtitle: tasksCompletedToday == 1 ? "task" : "tasks",
                    color: .nexusGreen
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Recent Activity Section

private extension HomeView {
    var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentActivityHeader

            if recentNotes.isEmpty, upcomingTasks.isEmpty {
                emptyStateView
            } else {
                recentActivityList
            }
        }
    }

    var recentActivityHeader: some View {
        HStack {
            Text("Recent Activity")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    var recentActivityList: some View {
        VStack(spacing: 8) {
            ForEach(upcomingTasks.prefix(3)) { task in
                ActivityRow(
                    icon: "checkmark.circle",
                    title: task.title,
                    subtitle: task.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No due date",
                    color: .tasksColor
                )
                .onTapGesture { selectedTask = task }
            }

            ForEach(recentNotes.prefix(3)) { note in
                ActivityRow(
                    icon: "doc.text",
                    title: note.title.isEmpty ? "Untitled Note" : note.title,
                    subtitle: note.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    color: .notesColor
                )
                .onTapGesture { selectedNote = note }
            }
        }
    }

    var emptyStateView: some View {
        NexusCard {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.nexusPurple)

                Text("Welcome to Nexus")
                    .font(.nexusHeadline)

                Text("Start by creating your first note or task")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Computed Properties

private extension HomeView {
    var userName: String? {
        NSUbiquitousKeyValueStore.default.string(forKey: "user_full_name")
    }

    var firstName: String? {
        guard let name = userName, !name.isEmpty else { return nil }
        return name.components(separatedBy: " ").first
    }

    var tasksCompletedToday: Int {
        let calendar = Calendar.current
        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }.count
    }
}

// MARK: - Actions

private extension HomeView {
    func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good Morning"
        case 12..<17: timeGreeting = "Good Afternoon"
        case 17..<21: timeGreeting = "Good Evening"
        default: timeGreeting = "Good Night"
        }

        if let name = firstName {
            greeting = "\(timeGreeting), \(name)"
        } else {
            greeting = timeGreeting
        }
    }

    func handleWidgetTap(_ widget: HomeWidget) {
        switch widget {
        case .notes:
            showNotes = true
        case .tasks:
            showTasks = true
        case .calendar:
            showCalendar = true
        case .subscriptions:
            showSubscriptions = true
        case .budgets:
            showBudgets = true
        case .healthSummary:
            showHealthEntry = true
        case .recentTransactions:
            showNewTransaction = true
        case .house:
            showHouse = true
        case .upcomingBills:
            showSubscriptions = true
        case .currencyConverter:
            showNewTransaction = true
        }
    }
}

// MARK: - Sheet Modifier

private struct SheetModifier: ViewModifier {
    @Binding var showSettings: Bool
    @Binding var showNewNote: Bool
    @Binding var showNewTask: Bool
    @Binding var showNewTransaction: Bool
    @Binding var showHealthEntry: Bool
    @Binding var showInsights: Bool
    @Binding var showWidgetEditor: Bool
    @Binding var selectedNote: NoteModel?
    @Binding var selectedTask: TaskModel?
    @Binding var showSubscriptions: Bool
    @Binding var showBudgets: Bool
    @Binding var showHouse: Bool
    @Binding var showNotes: Bool
    @Binding var showTasks: Bool
    @Binding var showCalendar: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showNewNote) { NoteEditorView(note: nil) }
            .sheet(isPresented: $showNewTask) { TaskEditorView(task: nil) }
            .sheet(isPresented: $showNewTransaction) { TransactionEditorView(transaction: nil) }
            .sheet(isPresented: $showHealthEntry) { HealthEntryEditorView() }
            .sheet(isPresented: $showInsights) { InsightsView() }
            .sheet(item: $selectedNote) { note in NoteEditorView(note: note) }
            .sheet(item: $selectedTask) { task in TaskEditorView(task: task) }
            .sheet(isPresented: $showWidgetEditor) { WidgetEditorSheet() }
            .sheet(isPresented: $showSubscriptions) { SubscriptionsView() }
            .sheet(isPresented: $showBudgets) { BudgetView() }
            .sheet(isPresented: $showHouse) { HouseView() }
            .sheet(isPresented: $showNotes) { NotesView() }
            .sheet(isPresented: $showTasks) { TasksView() }
            .sheet(isPresented: $showCalendar) { CalendarView() }
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(title)
                .font(.nexusCaption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background { cardBackground }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.nexusSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.nexusBorder, lineWidth: 1)
            }
    }
}

// MARK: - Insight Item

private struct InsightItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.nexusTitle2)
                .foregroundStyle(color)

            Text(subtitle)
                .font(.nexusCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            iconView
            textContent
            Spacer()
            chevronIcon
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(color.opacity(0.15))
            }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.nexusSubheadline)
                .lineLimit(1)

            Text(subtitle)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Home Widget Card

private struct HomeWidgetCard: View {
    let widget: HomeWidget
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        HStack(spacing: 8) {
            iconView
            titleText
            Spacer(minLength: 4)
            chevronIcon
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background { cardBackground }
    }

    private var iconView: some View {
        Image(systemName: widget.icon)
            .font(.system(size: 18))
            .foregroundStyle(widget.color)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(widget.color.opacity(0.15))
            }
    }

    private var titleText: some View {
        Text(widget.title)
            .font(.nexusSubheadline)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.nexusSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.nexusBorder, lineWidth: 1)
            }
    }
}

// MARK: - Widget Editor Sheet

struct WidgetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var widgetManager = HomeWidgetManager.shared

    var body: some View {
        NavigationStack {
            List {
                activeWidgetsSection
                availableWidgetsSection
            }
            .navigationTitle("Edit Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .environment(\.editMode, .constant(.active))
        }
    }
}

// MARK: - Widget Editor Toolbar

private extension WidgetEditorSheet {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }
}

// MARK: - Widget Editor Sections

private extension WidgetEditorSheet {
    var activeWidgetsSection: some View {
        Section {
            if widgetManager.selectedWidgets.isEmpty {
                Text("No widgets added")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(widgetManager.selectedWidgets) { widget in
                    activeWidgetRow(widget)
                }
                .onMove { source, destination in
                    widgetManager.moveWidget(from: source, to: destination)
                }
            }
        } header: {
            Text("Active Widgets")
        } footer: {
            Text("Drag to reorder. Tap minus to remove.")
        }
    }

    var availableWidgetsSection: some View {
        Section("Available Widgets") {
            ForEach(HomeWidget.allCases.filter { !widgetManager.isSelected($0) }) { widget in
                availableWidgetRow(widget)
            }
        }
    }

    func activeWidgetRow(_ widget: HomeWidget) -> some View {
        HStack(spacing: 12) {
            Image(systemName: widget.icon)
                .foregroundStyle(widget.color)
                .frame(width: 28)

            Text(widget.title)

            Spacer()

            Button {
                withAnimation { widgetManager.removeWidget(widget) }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    func availableWidgetRow(_ widget: HomeWidget) -> some View {
        HStack(spacing: 12) {
            Image(systemName: widget.icon)
                .foregroundStyle(widget.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(widget.title)
                Text(widget.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { widgetManager.addWidget(widget) }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
