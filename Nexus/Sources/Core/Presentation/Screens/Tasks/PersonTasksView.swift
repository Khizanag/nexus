import SwiftUI
import SwiftData

struct PersonTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]

    let person: PersonModel

    @State private var viewingTask: TaskModel?
    @State private var editingTask: TaskModel?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .background(Color.nexusBackground)
                .navigationTitle(person.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(item: $viewingTask) { task in
                    TaskDetailView(task: task)
                }
                .sheet(item: $editingTask) { task in
                    TaskEditorView(task: task)
                }
        }
    }
}

// MARK: - Toolbar

private extension PersonTasksView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
        }
    }
}

// MARK: - Content

private extension PersonTasksView {
    @ViewBuilder
    var content: some View {
        if assignedTasks.isEmpty {
            emptyState
        } else {
            tasksList
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            personAvatar

            Text("No Assigned Tasks")
                .font(.nexusTitle3)

            Text("\(person.name) has no tasks assigned yet")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    var personAvatar: some View {
        Text(person.initials)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 80, height: 80)
            .background(Circle().fill(Color(hex: person.colorHex) ?? .nexusPurple))
    }

    var tasksList: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if !pendingTasks.isEmpty {
                    taskSection(title: "Pending", tasks: pendingTasks, showCount: true)
                }

                if !completedTasks.isEmpty {
                    taskSection(title: "Completed", tasks: completedTasks, showCount: true)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Header Section

private extension PersonTasksView {
    var headerSection: some View {
        HStack(spacing: 16) {
            personAvatar

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(person.name)
                        .font(.nexusTitle3)
                        .fontWeight(.semibold)

                    if person.isLinkedToContact {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.nexusBlue)
                    }
                }

                HStack(spacing: 12) {
                    statBadge(count: pendingTasks.count, label: "pending", color: .nexusOrange)
                    statBadge(count: completedTasks.count, label: "done", color: .nexusGreen)
                }
            }

            Spacer()
        }
        .padding(20)
        .background { sectionBackground }
    }

    func statBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(label)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Task Section

private extension PersonTasksView {
    func taskSection(title: String, tasks: [TaskModel], showCount: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.nexusCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                if showCount {
                    Text("\(tasks.count)")
                        .font(.nexusCaption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.nexusBorder))
                }
            }
            .padding(.horizontal, 4)

            LazyVStack(spacing: 10) {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    func taskRow(_ task: TaskModel) -> some View {
        HStack(spacing: 14) {
            completionIndicator(task)
            taskInfo(task)
            Spacer()
            chevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background { sectionBackground }
        .onTapGesture {
            viewingTask = task
        }
        .contextMenu {
            taskContextMenu(task)
        }
    }

    func completionIndicator(_ task: TaskModel) -> some View {
        ZStack {
            if task.isCompleted {
                Circle()
                    .fill(Color.nexusGreen)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(priorityColor(task.priority), lineWidth: 2.5)
                    .frame(width: 24, height: 24)
            }
        }
    }

    func taskInfo(_ task: TaskModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            if let dueDate = task.dueDate {
                dueDateBadge(dueDate, isCompleted: task.isCompleted)
            }
        }
    }

    var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
    }

    func dueDateBadge(_ date: Date, isCompleted: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 9, weight: .semibold))
            Text(formatDueDate(date))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(dueDateColor(date, isCompleted: isCompleted))
        .opacity(isCompleted ? 0.6 : 1)
    }

    @ViewBuilder
    func taskContextMenu(_ task: TaskModel) -> some View {
        Button {
            viewingTask = task
        } label: {
            Label("View Task", systemImage: "eye")
        }

        Button {
            editingTask = task
        } label: {
            Label("Edit Task", systemImage: "pencil")
        }
    }
}

// MARK: - Computed Properties

private extension PersonTasksView {
    var assignedTasks: [TaskModel] {
        allTasks.filter { task in
            task.assignees?.contains { $0.id == person.id } == true
        }
    }

    var pendingTasks: [TaskModel] {
        assignedTasks.filter { !$0.isCompleted }
    }

    var completedTasks: [TaskModel] {
        assignedTasks.filter { $0.isCompleted }
    }
}

// MARK: - Helper Views

private extension PersonTasksView {
    var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.nexusSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.nexusBorder, lineWidth: 1)
            }
    }
}

// MARK: - Helper Methods

private extension PersonTasksView {
    func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: .nexusRed
        case .high: .nexusOrange
        case .medium: .nexusBlue
        case .low: .secondary
        }
    }

    func dueDateColor(_ date: Date, isCompleted: Bool) -> Color {
        guard !isCompleted else { return .secondary }

        if Calendar.current.isDateInToday(date) {
            return .nexusOrange
        } else if date < Date() {
            return .nexusRed
        }
        return .secondary
    }

    func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days)d overdue"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Preview

#Preview {
    PersonTasksView(person: PersonModel(name: "John Doe"))
        .preferredColorScheme(.dark)
}
