import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]

    @State private var selectedFilter: TaskFilter = .all
    @State private var showNewTask = false
    @State private var selectedTask: TaskModel?

    private var filteredTasks: [TaskModel] {
        switch selectedFilter {
        case .all:
            allTasks.filter { !$0.isCompleted }
        case .today:
            allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInToday(dueDate) && !task.isCompleted
            }
        case .upcoming:
            allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate > Date() && !task.isCompleted
            }
        case .completed:
            allTasks.filter { $0.isCompleted }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredTasks) { task in
                            TaskRow(task: task, onToggle: {
                                toggleTask(task)
                            })
                            .onTapGesture {
                                selectedTask = task
                            }
                        }

                        if filteredTasks.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewTask) {
                TaskEditorView(task: nil)
            }
            .sheet(item: $selectedTask) { task in
                TaskEditorView(task: task)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { filter in
                    FilterChip(
                        title: filter.title,
                        isSelected: selectedFilter == filter,
                        count: countForFilter(filter)
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.nexusBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .completed ? "checkmark.circle" : "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(emptyStateTitle)
                .font(.nexusTitle3)

            Text(emptyStateSubtitle)
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: "No Tasks"
        case .today: "No Tasks Today"
        case .upcoming: "No Upcoming Tasks"
        case .completed: "No Completed Tasks"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .completed: "Complete some tasks to see them here"
        default: "Tap + to add a new task"
        }
    }

    private func countForFilter(_ filter: TaskFilter) -> Int {
        switch filter {
        case .all: allTasks.filter { !$0.isCompleted }.count
        case .today: allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate) && !task.isCompleted
        }.count
        case .upcoming: allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate > Date() && !task.isCompleted
        }.count
        case .completed: allTasks.filter { $0.isCompleted }.count
        }
    }

    private func toggleTask(_ task: TaskModel) {
        withAnimation(.spring(response: 0.3)) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? .now : nil
            task.updatedAt = .now

            if task.isCompleted {
                DefaultTaskNotificationService.shared.cancelReminder(for: task)
            } else if task.reminderDate != nil {
                Task {
                    await DefaultTaskNotificationService.shared.scheduleReminder(for: task)
                }
            }
        }
    }
}

// MARK: - Task Filter

private enum TaskFilter: String, CaseIterable, Identifiable {
    case all, today, upcoming, completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .completed: "Completed"
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.nexusSubheadline)

                if count > 0 {
                    Text("\(count)")
                        .font(.nexusCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.2) : Color.nexusBorder)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? Color.nexusPurple : Color.nexusSurface)
                    .overlay {
                        if !isSelected {
                            Capsule()
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                    }
            }
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: TaskModel
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(task.isCompleted ? .nexusGreen : priorityColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.nexusBody)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.nexusCaption)
                    }
                    .foregroundStyle(dueDateColor(dueDate))
                }
            }

            Spacer()

            if task.priority == .high || task.priority == .urgent {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(priorityColor)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
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

    private var priorityColor: Color {
        switch task.priority {
        case .low: .secondary
        case .medium: .nexusBlue
        case .high: .nexusOrange
        case .urgent: .nexusRed
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) {
            return .nexusOrange
        } else if date < Date() {
            return .nexusRed
        }
        return .secondary
    }
}

#Preview {
    TasksView()
        .preferredColorScheme(.dark)
}
