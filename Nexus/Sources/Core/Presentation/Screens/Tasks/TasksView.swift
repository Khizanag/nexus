import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]
    @Query(sort: \TaskGroupModel.order) private var taskGroups: [TaskGroupModel]

    @State private var selectedFilter: TaskFilter = .all
    @State private var groupingMode: TaskGrouping = .project
    @State private var sortMode: TaskSorting = .dateCreated
    @State private var sortAscending: Bool = false
    @State private var showNewTask = false
    @State private var selectedTask: TaskModel?
    @State private var toastMessage: String?
    @State private var toastIsCompletion: Bool = true
    @State private var recentlyChangedTaskId: UUID?
    @State private var taskIsLeaving: Bool = false
    @State private var showGroupEditor = false
    @State private var editingGroup: TaskGroupModel?
    @State private var collapsedGroups: Set<UUID> = []

    private var filteredTasks: [TaskModel] {
        let filtered: [TaskModel]
        switch selectedFilter {
        case .all:
            filtered = allTasks.filter { !$0.isCompleted }
        case .today:
            filtered = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInToday(dueDate) && !task.isCompleted
            }
        case .upcoming:
            filtered = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate > Date() && !task.isCompleted
            }
        case .completed:
            filtered = allTasks.filter { $0.isCompleted }
        }

        return sortTasks(filtered)
    }

    private func sortTasks(_ tasks: [TaskModel]) -> [TaskModel] {
        let sorted = tasks.sorted { task1, task2 in
            switch sortMode {
            case .dateCreated:
                return task1.createdAt > task2.createdAt
            case .dueDate:
                let date1 = task1.dueDate ?? Date.distantFuture
                let date2 = task2.dueDate ?? Date.distantFuture
                return date1 < date2
            case .priority:
                return task1.priority.sortOrder > task2.priority.sortOrder
            case .alphabetical:
                return task1.title.localizedCaseInsensitiveCompare(task2.title) == .orderedAscending
            }
        }
        return sortAscending ? sorted.reversed() : sorted
    }

    private var groupedTasks: [(String, [TaskModel], TaskGroupModel?)] {
        guard selectedFilter == .all else {
            return [("", filteredTasks, nil)]
        }

        switch groupingMode {
        case .none:
            return [("", filteredTasks, nil)]
        case .dueDate:
            return groupByDueDate(filteredTasks).map { ($0.0, $0.1, nil) }
        case .priority:
            return groupByPriority(filteredTasks).map { ($0.0, $0.1, nil) }
        case .project:
            return groupByProject(filteredTasks)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    filterBar

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedTasks, id: \.0) { title, tasks, group in
                                if let group {
                                    projectSection(group: group, tasks: tasks)
                                } else if title == "Inbox", groupingMode == .project {
                                    inboxSection(tasks: tasks)
                                } else if !title.isEmpty {
                                    taskGroupSection(title: title, tasks: tasks)
                                } else {
                                    ForEach(tasks) { task in
                                        taskRowView(task)
                                    }
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

                // Status toast - positioned directly above tab bar
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        statusToast(message: message, isCompletion: toastIsCompletion)
                            .padding(.bottom, 60)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
                    .zIndex(100)
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Group By") {
                            ForEach(TaskGrouping.allCases) { mode in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        groupingMode = mode
                                    }
                                } label: {
                                    Label(mode.title, systemImage: groupingMode == mode ? "checkmark" : "")
                                }
                            }
                        }

                        Divider()

                        Section("Sort By") {
                            ForEach(TaskSorting.allCases) { sort in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        if sortMode == sort {
                                            sortAscending.toggle()
                                        } else {
                                            sortMode = sort
                                            sortAscending = false
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if sortMode == sort {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }

                                        Text(sort.title)

                                        Spacer()

                                        if sortMode == sort {
                                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Image(systemName: sort.icon)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Divider()

                        Section("Projects") {
                            Button {
                                showGroupEditor = true
                            } label: {
                                Label("New Project", systemImage: "plus.circle")
                            }

                            if !taskGroups.isEmpty {
                                ForEach(taskGroups) { group in
                                    Button {
                                        editingGroup = group
                                    } label: {
                                        Label(group.name, systemImage: group.icon)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
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
            .sheet(isPresented: $showGroupEditor) {
                TaskGroupEditorView(group: nil)
            }
            .sheet(item: $editingGroup) { group in
                TaskGroupEditorView(group: group)
            }
        }
    }

    @ViewBuilder
    private func taskGroupSection(title: String, tasks: [TaskModel]) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.nexusCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\(tasks.count)")
                        .font(.nexusCaption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.nexusBorder))
                }
                .padding(.horizontal, 4)

                ForEach(tasks) { task in
                    taskRowView(task)
                }
            }
        }
    }

    @ViewBuilder
    private func projectSection(group: TaskGroupModel, tasks: [TaskModel]) -> some View {
        let isCollapsed = collapsedGroups.contains(group.id)
        let groupColor = Color(hex: group.colorHex) ?? .nexusPurple

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isCollapsed {
                        collapsedGroups.remove(group.id)
                    } else {
                        collapsedGroups.insert(group.id)
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    // Accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(groupColor)
                        .frame(width: 4)
                        .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(groupColor.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: group.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(groupColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.name)
                                .font(.nexusHeadline)
                                .foregroundStyle(.primary)

                            Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(groupColor.opacity(0.6))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nexusSurface)
                        .shadow(color: groupColor.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [groupColor.opacity(0.3), groupColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    editingGroup = group
                } label: {
                    Label("Edit Project", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteGroup(group)
                } label: {
                    Label("Delete Project", systemImage: "trash")
                }
            }

            if !isCollapsed, !tasks.isEmpty {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        taskRowView(task)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func deleteGroup(_ group: TaskGroupModel) {
        withAnimation(.spring(response: 0.3)) {
            modelContext.delete(group)
        }
    }

    @ViewBuilder
    private func inboxSection(tasks: [TaskModel]) -> some View {
        let isCollapsed = collapsedGroups.contains(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    let inboxId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                    if isCollapsed {
                        collapsedGroups.remove(inboxId)
                    } else {
                        collapsedGroups.insert(inboxId)
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    // Accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.nexusBlue)
                        .frame(width: 4)
                        .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.nexusBlue.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: "tray.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.nexusBlue)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Inbox")
                                .font(.nexusHeadline)
                                .foregroundStyle(.primary)

                            Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.nexusBlue.opacity(0.6))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nexusSurface)
                        .shadow(color: Color.nexusBlue.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.nexusBlue.opacity(0.3), Color.nexusBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)

            if !isCollapsed, !tasks.isEmpty {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        taskRowView(task)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func taskRowView(_ task: TaskModel) -> some View {
        TaskRow(
            task: task,
            isRecentlyChanged: recentlyChangedTaskId == task.id,
            isLeaving: taskIsLeaving && recentlyChangedTaskId == task.id,
            onToggle: {
                toggleTask(task)
            }
        )
        .onTapGesture {
            selectedTask = task
        }
    }

    private func statusToast(message: String, isCompletion: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isCompletion ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(isCompletion ? Color.nexusGreen : Color.nexusOrange)

            Text(message)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Text(isCompletion ? "Moved to Completed" : "Restored")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            (isCompletion ? Color.nexusGreen : Color.nexusOrange).opacity(0.3),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
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
        let wasCompleted = task.isCompleted
        let taskTitle = task.title

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Mark as recently changed for animation
        recentlyChangedTaskId = task.id
        taskIsLeaving = false

        if !wasCompleted {
            // Completing task
            toastIsCompletion = true

            // Show highlight and celebrate
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                task.isCompleted = true
                task.completedAt = .now
                task.updatedAt = .now
            }

            // Start "leaving" animation after celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    taskIsLeaving = true
                }
            }

            // Show toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4)) {
                    toastMessage = taskTitle
                }
            }

            // Hide toast and cleanup after longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.spring(response: 0.4)) {
                    toastMessage = nil
                    recentlyChangedTaskId = nil
                    taskIsLeaving = false
                }
            }

            DefaultTaskNotificationService.shared.cancelReminder(for: task)
        } else {
            // Uncompleting task
            toastIsCompletion = false

            // Animate restoration
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                task.isCompleted = false
                task.completedAt = nil
                task.updatedAt = .now
            }

            // Start "leaving" animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    taskIsLeaving = true
                }
            }

            // Show toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4)) {
                    toastMessage = taskTitle
                }
            }

            // Hide toast and cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.4)) {
                    toastMessage = nil
                    recentlyChangedTaskId = nil
                    taskIsLeaving = false
                }
            }

            if task.reminderDate != nil {
                Task {
                    await DefaultTaskNotificationService.shared.scheduleReminder(for: task)
                }
            }
        }
    }

    // MARK: - Grouping Logic

    private func groupByDueDate(_ tasks: [TaskModel]) -> [(String, [TaskModel])] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today)!

        var overdue: [TaskModel] = []
        var todayTasks: [TaskModel] = []
        var tomorrowTasks: [TaskModel] = []
        var thisWeek: [TaskModel] = []
        var later: [TaskModel] = []
        var noDate: [TaskModel] = []

        for task in tasks {
            guard let dueDate = task.dueDate else {
                noDate.append(task)
                continue
            }

            let dueDay = calendar.startOfDay(for: dueDate)

            if dueDay < today {
                overdue.append(task)
            } else if calendar.isDateInToday(dueDate) {
                todayTasks.append(task)
            } else if dueDay == tomorrow {
                tomorrowTasks.append(task)
            } else if dueDate < endOfWeek {
                thisWeek.append(task)
            } else {
                later.append(task)
            }
        }

        var result: [(String, [TaskModel])] = []
        if !overdue.isEmpty { result.append(("Overdue", overdue)) }
        if !todayTasks.isEmpty { result.append(("Today", todayTasks)) }
        if !tomorrowTasks.isEmpty { result.append(("Tomorrow", tomorrowTasks)) }
        if !thisWeek.isEmpty { result.append(("This Week", thisWeek)) }
        if !later.isEmpty { result.append(("Later", later)) }
        if !noDate.isEmpty { result.append(("No Due Date", noDate)) }

        return result
    }

    private func groupByPriority(_ tasks: [TaskModel]) -> [(String, [TaskModel])] {
        var urgent: [TaskModel] = []
        var high: [TaskModel] = []
        var medium: [TaskModel] = []
        var low: [TaskModel] = []

        for task in tasks {
            switch task.priority {
            case .urgent: urgent.append(task)
            case .high: high.append(task)
            case .medium: medium.append(task)
            case .low: low.append(task)
            }
        }

        var result: [(String, [TaskModel])] = []
        if !urgent.isEmpty { result.append(("Urgent", urgent)) }
        if !high.isEmpty { result.append(("High Priority", high)) }
        if !medium.isEmpty { result.append(("Medium Priority", medium)) }
        if !low.isEmpty { result.append(("Low Priority", low)) }

        return result
    }

    private func groupByProject(_ tasks: [TaskModel]) -> [(String, [TaskModel], TaskGroupModel?)] {
        var result: [(String, [TaskModel], TaskGroupModel?)] = []

        // Group tasks by their project
        for group in taskGroups {
            let groupTasks = tasks.filter { $0.group?.id == group.id }
            if !groupTasks.isEmpty {
                result.append((group.name, groupTasks, group))
            }
        }

        // Tasks without a project
        let ungroupedTasks = tasks.filter { $0.group == nil }
        if !ungroupedTasks.isEmpty {
            result.append(("Inbox", ungroupedTasks, nil))
        }

        return result
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

// MARK: - Task Grouping

private enum TaskGrouping: String, CaseIterable, Identifiable {
    case project, dueDate, priority, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project: "Project"
        case .dueDate: "Due Date"
        case .priority: "Priority"
        case .none: "None"
        }
    }
}

// MARK: - Task Sorting

private enum TaskSorting: String, CaseIterable, Identifiable {
    case dateCreated, dueDate, priority, alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateCreated: "Date Created"
        case .dueDate: "Due Date"
        case .priority: "Priority"
        case .alphabetical: "Alphabetical"
        }
    }

    var icon: String {
        switch self {
        case .dateCreated: "clock"
        case .dueDate: "calendar"
        case .priority: "flag"
        case .alphabetical: "textformat.abc"
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: TaskModel
    let isRecentlyChanged: Bool
    let isLeaving: Bool
    let onToggle: () -> Void

    @State private var checkmarkScale: CGFloat = 1.0
    @State private var showCelebration = false
    @State private var showStrikethrough = false

    private var highlightColor: Color {
        task.isCompleted ? Color.nexusGreen : Color.nexusOrange
    }

    private var priorityAccentColor: Color {
        switch task.priority {
        case .urgent: Color.nexusRed
        case .high: Color.nexusOrange
        case .medium: Color.nexusBlue
        case .low: Color.nexusTextTertiary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Priority accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(task.isCompleted ? Color.nexusGreen.opacity(0.5) : priorityAccentColor)
                .frame(width: 3)
                .padding(.vertical, 10)

            HStack(spacing: 14) {
                checkmarkButton
                taskContent
                Spacer(minLength: 8)
                trailingContent
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background { rowBackground }
        .overlay { celebrationOverlay }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .scaleEffect(isLeaving ? 0.92 : (isRecentlyChanged ? 1.02 : 1.0))
        .opacity(isLeaving ? 0.6 : 1.0)
        .offset(y: isLeaving ? (task.isCompleted ? 8 : -8) : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRecentlyChanged)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: isLeaving)
        .onChange(of: task.isCompleted) { _, newValue in
            if !newValue {
                showStrikethrough = false
                showCelebration = false
            }
        }
    }
}

// MARK: - TaskRow Components

private extension TaskRow {
    var checkmarkButton: some View {
        Button(action: handleToggle) {
            ZStack {
                if task.isCompleted {
                    // Completed state - solid green ring and fill
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.nexusGreen, Color.nexusGreen.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.nexusGreen.opacity(0.4), radius: 4, x: 0, y: 2)

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Uncompleted state - gradient ring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [priorityAccentColor, priorityAccentColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 28, height: 28)
                }
            }
            .scaleEffect(checkmarkScale)
        }
        .buttonStyle(.plain)
    }

    var taskContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.nexusBody)
                .fontWeight(.medium)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted || showStrikethrough, color: .secondary)
                .animation(.easeInOut(duration: 0.4), value: showStrikethrough)
                .lineLimit(2)

            if !task.notes.isEmpty || task.dueDate != nil || task.reminderDate != nil {
                HStack(spacing: 10) {
                    if let dueDate = task.dueDate {
                        dueDateBadge(dueDate)
                    }

                    if task.reminderDate != nil {
                        reminderBadge
                    }

                    if !task.notes.isEmpty {
                        notesBadge
                    }
                }
            }
        }
    }

    func dueDateBadge(_ dueDate: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: dueDateIcon(dueDate))
                .font(.system(size: 10, weight: .semibold))
            Text(formatDueDate(dueDate))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(dueDateColor(dueDate))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(dueDateColor(dueDate).opacity(0.12))
        }
        .opacity(task.isCompleted ? 0.5 : 1)
    }

    var reminderBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bell.fill")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(Color.nexusPurple)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.nexusPurple.opacity(0.12))
        }
        .opacity(task.isCompleted ? 0.5 : 1)
    }

    var notesBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "note.text")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(Color.nexusTextTertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.nexusTextTertiary.opacity(0.12))
        }
        .opacity(task.isCompleted ? 0.5 : 1)
    }

    func dueDateIcon(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "sun.max.fill"
        } else if date < Date() {
            return "exclamationmark.circle.fill"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "sunrise.fill"
        }
        return "calendar"
    }

    func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    @ViewBuilder
    var trailingContent: some View {
        HStack(spacing: 8) {
            if isLeaving {
                Image(systemName: task.isCompleted ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(highlightColor.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
            }

            if task.priority == .urgent {
                priorityBadge(icon: "flame.fill", color: .nexusRed)
            } else if task.priority == .high {
                priorityBadge(icon: "flag.fill", color: .nexusOrange)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }

    func priorityBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .opacity(task.isCompleted ? 0.4 : 1)
    }

    var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isRecentlyChanged ? highlightColor.opacity(0.08) : Color.nexusSurface)
            .shadow(
                color: isRecentlyChanged
                    ? highlightColor.opacity(0.15)
                    : Color.black.opacity(0.08),
                radius: isRecentlyChanged ? 8 : 4,
                x: 0,
                y: 2
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isRecentlyChanged
                            ? highlightColor.opacity(0.4)
                            : priorityAccentColor.opacity(task.isCompleted ? 0 : 0.15),
                        lineWidth: isRecentlyChanged ? 1.5 : 1
                    )
            }
    }

    @ViewBuilder
    var celebrationOverlay: some View {
        if showCelebration, task.isCompleted {
            CelebrationParticles()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - TaskRow Actions

private extension TaskRow {
    func handleToggle() {
        if !task.isCompleted {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                checkmarkScale = 1.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    checkmarkScale = 1.0
                }
            }
            showCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showStrikethrough = true
            }
        }
        onToggle()
    }

    func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) {
            return .nexusOrange
        } else if date < Date() {
            return .nexusRed
        }
        return .secondary
    }
}

// MARK: - Celebration Particles

private struct CelebrationParticles: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double, rotation: Double)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(
                            [Color.nexusGreen, Color.nexusTeal, Color.nexusBlue, Color.yellow].randomElement()!
                        )
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
            }
        }
    }

    private func createParticles(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2

        for i in 0..<8 {
            let angle = Double(i) * (360.0 / 8.0) * .pi / 180
            let distance: CGFloat = 60

            let startX = centerX
            let startY = centerY
            let endX = centerX + CGFloat(cos(angle)) * distance
            let endY = centerY + CGFloat(sin(angle)) * distance

            let particle = (
                id: i,
                x: startX,
                y: startY,
                scale: CGFloat(0.5),
                opacity: Double(1.0),
                rotation: Double.random(in: 0...360)
            )
            particles.append(particle)

            withAnimation(.easeOut(duration: 0.6)) {
                if let index = particles.firstIndex(where: { $0.id == i }) {
                    particles[index].x = endX
                    particles[index].y = endY
                    particles[index].scale = CGFloat.random(in: 0.8...1.2)
                    particles[index].rotation += Double.random(in: 90...180)
                }
            }

            withAnimation(.easeIn(duration: 0.3).delay(0.4)) {
                if let index = particles.firstIndex(where: { $0.id == i }) {
                    particles[index].opacity = 0
                }
            }
        }
    }
}

#Preview {
    TasksView()
        .preferredColorScheme(.dark)
}
