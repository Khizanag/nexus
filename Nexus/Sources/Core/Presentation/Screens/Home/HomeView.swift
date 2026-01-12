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

    // Widget navigation states
    @State private var showSubscriptions = false
    @State private var showBudgets = false
    @State private var showHealth = false
    @State private var showHouse = false
    @State private var showNotes = false
    @State private var showTasks = false
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
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
            .background(Color.nexusBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showNewNote) {
                NoteEditorView(note: nil)
            }
            .sheet(isPresented: $showNewTask) {
                TaskEditorView(task: nil)
            }
            .sheet(isPresented: $showNewTransaction) {
                TransactionEditorView(transaction: nil)
            }
            .sheet(isPresented: $showHealthEntry) {
                HealthEntryEditorView()
            }
            .sheet(isPresented: $showInsights) {
                InsightsView()
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
            }
            .sheet(item: $selectedTask) { task in
                TaskEditorView(task: task)
            }
            .sheet(isPresented: $showWidgetEditor) {
                WidgetEditorSheet()
            }
            .sheet(isPresented: $showSubscriptions) {
                SubscriptionsView()
            }
            .sheet(isPresented: $showBudgets) {
                BudgetView()
            }
            .sheet(isPresented: $showHouse) {
                HouseView()
            }
            .sheet(isPresented: $showNotes) {
                NotesView()
            }
            .sheet(isPresented: $showTasks) {
                TasksView()
            }
            .sheet(isPresented: $showCalendar) {
                CalendarView()
            }
        }
        .onAppear {
            updateGreeting()
        }
    }

    // MARK: - Widgets Section

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Widgets")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showWidgetEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                        Text("Edit")
                    }
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusPurple)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(widgetManager.selectedWidgets) { widget in
                    HomeWidgetCard(widget: widget) {
                        handleWidgetTap(widget)
                    }
                }
            }
        }
    }

    private func handleWidgetTap(_ widget: HomeWidget) {
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

    // MARK: - Header

    private var headerSection: some View {
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

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

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

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Insights")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("View All") {
                    showInsights = true
                }
                .font(.nexusSubheadline)
                .foregroundStyle(Color.nexusPurple)
            }

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

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if recentNotes.isEmpty, upcomingTasks.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingTasks.prefix(3)) { task in
                        ActivityRow(
                            icon: "checkmark.circle",
                            title: task.title,
                            subtitle: task.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No due date",
                            color: .tasksColor
                        )
                        .onTapGesture {
                            selectedTask = task
                        }
                    }

                    ForEach(recentNotes.prefix(3)) { note in
                        ActivityRow(
                            icon: "doc.text",
                            title: note.title.isEmpty ? "Untitled Note" : note.title,
                            subtitle: note.updatedAt.formatted(date: .abbreviated, time: .shortened),
                            color: .notesColor
                        )
                        .onTapGesture {
                            selectedNote = note
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
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

    private var userName: String? {
        NSUbiquitousKeyValueStore.default.string(forKey: "user_full_name")
    }

    private var firstName: String? {
        guard let name = userName, !name.isEmpty else { return nil }
        return name.components(separatedBy: " ").first
    }

    private func updateGreeting() {
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

    private var tasksCompletedToday: Int {
        let calendar = Calendar.current
        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }.count
    }
}

// MARK: - Supporting Views

private struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

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

private struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.nexusSubheadline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
    }
}

// MARK: - Home Widget Card

private struct HomeWidgetCard: View {
    let widget: HomeWidget
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: widget.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(widget.color)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(widget.color.opacity(0.15))
                    }

                Text(widget.title)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Editor Sheet

struct WidgetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var widgetManager = HomeWidgetManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if widgetManager.selectedWidgets.isEmpty {
                        Text("No widgets added")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(widgetManager.selectedWidgets) { widget in
                            HStack(spacing: 12) {
                                Image(systemName: widget.icon)
                                    .foregroundStyle(widget.color)
                                    .frame(width: 28)

                                Text(widget.title)

                                Spacer()

                                Button {
                                    withAnimation {
                                        widgetManager.removeWidget(widget)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
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

                Section("Available Widgets") {
                    ForEach(HomeWidget.allCases.filter { !widgetManager.isSelected($0) }) { widget in
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
                                withAnimation {
                                    widgetManager.addWidget(widget)
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
