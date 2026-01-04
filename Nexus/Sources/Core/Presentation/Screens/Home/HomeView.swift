import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NoteModel.updatedAt, order: .reverse)
    private var recentNotes: [NoteModel]

    @Query(filter: #Predicate<TaskModel> { !$0.isCompleted }, sort: \TaskModel.dueDate)
    private var upcomingTasks: [TaskModel]

    @State private var greeting: String = ""
    @State private var showSettings = false
    @State private var showNewNote = false
    @State private var showNewTask = false
    @State private var showNewTransaction = false
    @State private var showHealthEntry = false
    @State private var showInsights = false
    @State private var selectedNote: NoteModel?
    @State private var selectedTask: TaskModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    quickActionsSection
                    insightsSection
                    recentActivitySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
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
        }
        .onAppear {
            updateGreeting()
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
                        title: "Streak",
                        value: "\(calculateStreak())",
                        subtitle: "days",
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

            if recentNotes.isEmpty && upcomingTasks.isEmpty {
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

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: greeting = "Good Morning"
        case 12..<17: greeting = "Good Afternoon"
        case 17..<21: greeting = "Good Evening"
        default: greeting = "Good Night"
        }
    }

    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        while true {
            let hasActivity = recentNotes.contains { note in
                calendar.isDate(note.updatedAt, inSameDayAs: currentDate)
            } || upcomingTasks.contains { task in
                if let completedAt = task.completedAt {
                    return calendar.isDate(completedAt, inSameDayAs: currentDate)
                }
                return false
            }

            if hasActivity {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }

        return streak
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

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
