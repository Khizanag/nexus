import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]
    @Query(sort: \TaskGroupModel.order) private var taskGroups: [TaskGroupModel]

    @State private var selectedFilter: TaskFilter = .all
    @State private var groupingMode: TaskGrouping = .project
    @State private var sortMode: TaskSorting = .dateCreated
    @State private var sortAscending = false
    @State private var showNewTask = false
    @State private var viewingTask: TaskModel?
    @State private var editingTask: TaskModel?
    @State private var toastMessage: String?
    @State private var toastIsCompletion = true
    @State private var recentlyChangedTaskId: UUID?
    @State private var taskIsLeaving = false
    @State private var showGroupEditor = false
    @State private var editingGroup: TaskGroupModel?
    @State private var collapsedGroups: Set<UUID> = []

    private let inboxId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                toastOverlay
            }
            .navigationTitle("Tasks")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showNewTask) {
                TaskEditorView(task: nil)
            }
            .sheet(item: $viewingTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(item: $editingTask) { task in
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
}

// MARK: - Main Content

private extension TasksView {
    var mainContent: some View {
        VStack(spacing: 0) {
            filterBar
            taskList
        }
        .background(Color.nexusBackground)
    }

    var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(groupedTasks, id: \.0) { title, tasks, group in
                    sectionContent(title: title, tasks: tasks, group: group)
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

    @ViewBuilder
    func sectionContent(title: String, tasks: [TaskModel], group: TaskGroupModel?) -> some View {
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
}

// MARK: - Filter Bar

private extension TasksView {
    var filterBar: some View {
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

    func countForFilter(_ filter: TaskFilter) -> Int {
        switch filter {
        case .all:
            allTasks.filter { !$0.isCompleted }.count
        case .today:
            allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInToday(dueDate) && !task.isCompleted
            }.count
        case .upcoming:
            allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate > Date() && !task.isCompleted
            }.count
        case .completed:
            allTasks.filter { $0.isCompleted }.count
        }
    }
}

// MARK: - Sections

private extension TasksView {
    @ViewBuilder
    func taskGroupSection(title: String, tasks: [TaskModel]) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: title, count: tasks.count)

                ForEach(tasks) { task in
                    taskRowView(task)
                }
            }
        }
    }

    func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.nexusCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text("\(count)")
                .font(.nexusCaption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.nexusBorder))
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    func projectSection(group: TaskGroupModel, tasks: [TaskModel]) -> some View {
        let isCollapsed = collapsedGroups.contains(group.id)
        let groupColor = Color(hex: group.colorHex) ?? .nexusPurple

        VStack(alignment: .leading, spacing: 0) {
            projectHeader(group: group, tasks: tasks, isCollapsed: isCollapsed, color: groupColor)
                .contextMenu {
                    projectContextMenu(group: group)
                }

            if !isCollapsed, !tasks.isEmpty {
                projectTasks(tasks)
            }
        }
    }

    func projectHeader(group: TaskGroupModel, tasks: [TaskModel], isCollapsed: Bool, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                toggleCollapsed(group.id)
            }
        } label: {
            HStack(spacing: 0) {
                accentBar(color: color)
                projectHeaderContent(group: group, tasks: tasks, isCollapsed: isCollapsed, color: color)
            }
            .background { projectCardBackground(color: color) }
            .overlay { projectCardBorder(color: color) }
        }
        .buttonStyle(.plain)
    }

    func accentBar(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 4)
            .padding(.vertical, 8)
    }

    func projectHeaderContent(group: TaskGroupModel, tasks: [TaskModel], isCollapsed: Bool, color: Color) -> some View {
        HStack(spacing: 12) {
            projectIcon(icon: group.icon, color: color)
            projectInfo(name: group.name, taskCount: tasks.count)
            Spacer()
            chevron(isCollapsed: isCollapsed, color: color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    func projectIcon(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    func projectInfo(name: String, taskCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.nexusHeadline)
                .foregroundStyle(.primary)

            Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    func chevron(isCollapsed: Bool, color: Color) -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color.opacity(0.6))
            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
    }

    func projectCardBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.nexusSurface)
            .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    func projectCardBorder(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    @ViewBuilder
    func projectContextMenu(group: TaskGroupModel) -> some View {
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

    func projectTasks(_ tasks: [TaskModel]) -> some View {
        VStack(spacing: 10) {
            ForEach(tasks) { task in
                taskRowView(task)
            }
        }
        .padding(.top, 12)
        .padding(.leading, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    func inboxSection(tasks: [TaskModel]) -> some View {
        let isCollapsed = collapsedGroups.contains(inboxId)

        VStack(alignment: .leading, spacing: 0) {
            inboxHeader(tasks: tasks, isCollapsed: isCollapsed)

            if !isCollapsed, !tasks.isEmpty {
                projectTasks(tasks)
            }
        }
    }

    func inboxHeader(tasks: [TaskModel], isCollapsed: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                toggleCollapsed(inboxId)
            }
        } label: {
            HStack(spacing: 0) {
                accentBar(color: Color.nexusBlue)
                inboxHeaderContent(tasks: tasks, isCollapsed: isCollapsed)
            }
            .background { projectCardBackground(color: Color.nexusBlue) }
            .overlay { projectCardBorder(color: Color.nexusBlue) }
        }
        .buttonStyle(.plain)
    }

    func inboxHeaderContent(tasks: [TaskModel], isCollapsed: Bool) -> some View {
        HStack(spacing: 12) {
            projectIcon(icon: "tray.fill", color: Color.nexusBlue)
            projectInfo(name: "Inbox", taskCount: tasks.count)
            Spacer()
            chevron(isCollapsed: isCollapsed, color: Color.nexusBlue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

// MARK: - Task Row

private extension TasksView {
    @ViewBuilder
    func taskRowView(_ task: TaskModel) -> some View {
        TaskRow(
            task: task,
            isRecentlyChanged: recentlyChangedTaskId == task.id,
            isLeaving: taskIsLeaving && recentlyChangedTaskId == task.id,
            onToggle: { toggleTask(task) }
        )
        .onTapGesture {
            viewingTask = task
        }
        .contextMenu {
            taskContextMenu(task)
        }
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

        Button {
            toggleTask(task)
        } label: {
            if task.isCompleted {
                Label("Mark as Incomplete", systemImage: "arrow.uturn.backward")
            } else {
                Label("Mark as Complete", systemImage: "checkmark.circle")
            }
        }

        Divider()

        Button {
            duplicateTask(task)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        if let url = task.url, let taskURL = URL(string: url) {
            Button {
                UIApplication.shared.open(taskURL)
            } label: {
                Label("Open Link", systemImage: "link")
            }
        }

        Divider()

        Menu {
            ForEach(TaskPriority.allCases, id: \.self) { priority in
                Button {
                    changePriority(task, to: priority)
                } label: {
                    if task.priority == priority {
                        Label(priority.rawValue.capitalized, systemImage: "checkmark")
                    } else {
                        Text(priority.rawValue.capitalized)
                    }
                }
            }
        } label: {
            Label("Priority", systemImage: "flag")
        }

        if !taskGroups.isEmpty {
            Menu {
                Button {
                    moveToProject(task, project: nil)
                } label: {
                    if task.group == nil {
                        Label("Inbox", systemImage: "checkmark")
                    } else {
                        Label("Inbox", systemImage: "tray")
                    }
                }

                ForEach(taskGroups) { group in
                    Button {
                        moveToProject(task, project: group)
                    } label: {
                        if task.group?.id == group.id {
                            Label(group.name, systemImage: "checkmark")
                        } else {
                            Label(group.name, systemImage: group.icon)
                        }
                    }
                }
            } label: {
                Label("Move to Project", systemImage: "folder")
            }
        }

        Divider()

        Button(role: .destructive) {
            deleteTask(task)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Empty State

private extension TasksView {
    var emptyState: some View {
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

    var emptyStateTitle: String {
        switch selectedFilter {
        case .all: "No Tasks"
        case .today: "No Tasks Today"
        case .upcoming: "No Upcoming Tasks"
        case .completed: "No Completed Tasks"
        }
    }

    var emptyStateSubtitle: String {
        switch selectedFilter {
        case .completed: "Complete some tasks to see them here"
        default: "Tap + to add a new task"
        }
    }
}

// MARK: - Toast

private extension TasksView {
    @ViewBuilder
    var toastOverlay: some View {
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

    func statusToast(message: String, isCompletion: Bool) -> some View {
        HStack(spacing: 12) {
            toastIcon(isCompletion: isCompletion)
            toastText(message: message)
            Spacer()
            toastStatus(isCompletion: isCompletion)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background { toastBackground(isCompletion: isCompletion) }
        .padding(.horizontal, 20)
    }

    func toastIcon(isCompletion: Bool) -> some View {
        Image(systemName: isCompletion ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(isCompletion ? Color.nexusGreen : Color.nexusOrange)
    }

    func toastText(message: String) -> some View {
        Text(message)
            .font(.nexusSubheadline)
            .fontWeight(.medium)
            .lineLimit(1)
    }

    func toastStatus(isCompletion: Bool) -> some View {
        Text(isCompletion ? "Moved to Completed" : "Restored")
            .font(.nexusCaption)
            .foregroundStyle(.secondary)
    }

    func toastBackground(isCompletion: Bool) -> some View {
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
}

// MARK: - Toolbar

private extension TasksView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            filterMenu
        }
        ToolbarItem(placement: .topBarTrailing) {
            addButton
        }
    }

    var filterMenu: some View {
        Menu {
            groupBySection
            Divider()
            sortBySection
            Divider()
            projectsSection
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    var groupBySection: some View {
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
    }

    var sortBySection: some View {
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
                    sortMenuItem(sort)
                }
            }
        }
    }

    func sortMenuItem(_ sort: TaskSorting) -> some View {
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

    var projectsSection: some View {
        Section("Projects") {
            Button {
                showGroupEditor = true
            } label: {
                Label("New Project", systemImage: "plus.circle")
            }

            ForEach(taskGroups) { group in
                Button {
                    editingGroup = group
                } label: {
                    Label(group.name, systemImage: group.icon)
                }
            }
        }
    }

    var addButton: some View {
        Button {
            showNewTask = true
        } label: {
            Image(systemName: "plus")
        }
    }
}

// MARK: - Computed Properties

private extension TasksView {
    var filteredTasks: [TaskModel] {
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

    var groupedTasks: [(String, [TaskModel], TaskGroupModel?)] {
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
}

// MARK: - Actions

private extension TasksView {
    func toggleCollapsed(_ id: UUID) {
        if collapsedGroups.contains(id) {
            collapsedGroups.remove(id)
        } else {
            collapsedGroups.insert(id)
        }
    }

    func deleteGroup(_ group: TaskGroupModel) {
        withAnimation(.spring(response: 0.3)) {
            modelContext.delete(group)
        }
    }

    func toggleTask(_ task: TaskModel) {
        let wasCompleted = task.isCompleted
        let taskTitle = task.title

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        recentlyChangedTaskId = task.id
        taskIsLeaving = false

        if !wasCompleted {
            completeTask(task, title: taskTitle)
        } else {
            uncompleteTask(task, title: taskTitle)
        }
    }

    func completeTask(_ task: TaskModel, title: String) {
        toastIsCompletion = true

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            task.isCompleted = true
            task.completedAt = .now
            task.updatedAt = .now
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                taskIsLeaving = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4)) {
                toastMessage = title
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.4)) {
                toastMessage = nil
                recentlyChangedTaskId = nil
                taskIsLeaving = false
            }
        }

        DefaultTaskNotificationService.shared.cancelReminder(for: task)
    }

    func uncompleteTask(_ task: TaskModel, title: String) {
        toastIsCompletion = false

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            task.isCompleted = false
            task.completedAt = nil
            task.updatedAt = .now
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                taskIsLeaving = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4)) {
                toastMessage = title
            }
        }

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

    func duplicateTask(_ task: TaskModel) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let newTask = TaskModel(
            title: task.title,
            notes: task.notes,
            url: task.url,
            priority: task.priority,
            dueDate: task.dueDate,
            reminderDate: nil,
            group: task.group,
            assignees: task.assignees
        )
        modelContext.insert(newTask)
    }

    func changePriority(_ task: TaskModel, to priority: TaskPriority) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.3)) {
            task.priority = priority
            task.updatedAt = .now
        }
    }

    func moveToProject(_ task: TaskModel, project: TaskGroupModel?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.3)) {
            task.group = project
            task.updatedAt = .now
        }
    }

    func deleteTask(_ task: TaskModel) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        DefaultTaskNotificationService.shared.cancelReminder(for: task)

        withAnimation(.spring(response: 0.3)) {
            modelContext.delete(task)
        }
    }
}

// MARK: - Sorting & Grouping

private extension TasksView {
    func sortTasks(_ tasks: [TaskModel]) -> [TaskModel] {
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

    func groupByDueDate(_ tasks: [TaskModel]) -> [(String, [TaskModel])] {
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

    func groupByPriority(_ tasks: [TaskModel]) -> [(String, [TaskModel])] {
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

    func groupByProject(_ tasks: [TaskModel]) -> [(String, [TaskModel], TaskGroupModel?)] {
        var result: [(String, [TaskModel], TaskGroupModel?)] = []

        for group in taskGroups {
            let groupTasks = tasks.filter { $0.group?.id == group.id }
            if !groupTasks.isEmpty {
                result.append((group.name, groupTasks, group))
            }
        }

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

    var body: some View {
        HStack(spacing: 0) {
            priorityBar
            contentRow
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

// MARK: - TaskRow Subviews

private extension TaskRow {
    var priorityBar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(task.isCompleted ? Color.nexusGreen.opacity(0.5) : priorityAccentColor)
            .frame(width: 3)
            .padding(.vertical, 10)
    }

    var contentRow: some View {
        HStack(spacing: 14) {
            checkmarkButton
            taskContent
            Spacer(minLength: 8)
            trailingContent
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    var checkmarkButton: some View {
        Button(action: handleToggle) {
            ZStack {
                if task.isCompleted {
                    completedCheckmark
                } else {
                    uncompletedCheckmark
                }
            }
            .scaleEffect(checkmarkScale)
        }
        .buttonStyle(.plain)
    }

    var completedCheckmark: some View {
        ZStack {
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
        }
    }

    var uncompletedCheckmark: some View {
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

    var taskContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleText
            notesText
            badgesRow
        }
    }

    var titleText: some View {
        Text(task.title)
            .font(.nexusBody)
            .fontWeight(.medium)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
            .strikethrough(task.isCompleted || showStrikethrough, color: .secondary)
            .animation(.easeInOut(duration: 0.4), value: showStrikethrough)
            .lineLimit(2)
    }

    @ViewBuilder
    var notesText: some View {
        if !task.notes.isEmpty {
            Text(task.notes)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .opacity(task.isCompleted ? 0.6 : 1)
        }
    }

    @ViewBuilder
    var badgesRow: some View {
        if hasBadges {
            HStack(spacing: 8) {
                if let dueDate = task.dueDate {
                    dueDateBadge(dueDate)
                }

                if task.reminderDate != nil {
                    reminderBadge
                }

                if task.url != nil {
                    urlBadge
                }

                if let assignees = task.assignees, !assignees.isEmpty {
                    assigneesBadge(assignees)
                }
            }
        }
    }

    var trailingContent: some View {
        HStack(spacing: 8) {
            if isLeaving {
                Image(systemName: task.isCompleted ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(highlightColor.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
            }

            if task.priority == .urgent {
                priorityIcon(icon: "flame.fill", color: .nexusRed)
            } else if task.priority == .high {
                priorityIcon(icon: "flag.fill", color: .nexusOrange)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }

    func priorityIcon(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .opacity(task.isCompleted ? 0.4 : 1)
    }

    var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isRecentlyChanged ? highlightColor.opacity(0.08) : Color.nexusSurface)
            .shadow(
                color: isRecentlyChanged ? highlightColor.opacity(0.15) : Color.black.opacity(0.08),
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

// MARK: - TaskRow Badges

private extension TaskRow {
    var hasBadges: Bool {
        task.dueDate != nil ||
        task.reminderDate != nil ||
        task.url != nil ||
        (task.assignees?.isEmpty == false)
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
            Capsule().fill(dueDateColor(dueDate).opacity(0.12))
        }
        .opacity(task.isCompleted ? 0.5 : 1)
    }

    var reminderBadge: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.nexusPurple)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.nexusPurple.opacity(0.12))
            }
            .opacity(task.isCompleted ? 0.5 : 1)
    }

    var urlBadge: some View {
        Image(systemName: "link")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.nexusBlue)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.nexusBlue.opacity(0.12))
            }
            .opacity(task.isCompleted ? 0.5 : 1)
    }

    func assigneesBadge(_ assignees: [PersonModel]) -> some View {
        HStack(spacing: -4) {
            ForEach(Array(assignees.prefix(2))) { person in
                let avatarColor = Color(hex: person.colorHex) ?? .nexusPurple

                Text(person.initials)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(avatarColor))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }

            if assignees.count > 2 {
                let overflowCount = assignees.count - 2
                let displayText = overflowCount > 99 ? "+99" : "+\(overflowCount)"

                Text(displayText)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        }
        .opacity(task.isCompleted ? 0.5 : 1)
    }
}

// MARK: - TaskRow Helpers

private extension TaskRow {
    var highlightColor: Color {
        task.isCompleted ? Color.nexusGreen : Color.nexusOrange
    }

    var priorityAccentColor: Color {
        switch task.priority {
        case .urgent: Color.nexusRed
        case .high: Color.nexusOrange
        case .medium: Color.nexusBlue
        case .low: Color.nexusTextTertiary
        }
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

    func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) {
            return .nexusOrange
        } else if date < Date() {
            return .nexusRed
        }
        return .secondary
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
}

// MARK: - Celebration Particles

private struct CelebrationParticles: View {
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(particle.color)
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
        let colors: [Color] = [.nexusGreen, .nexusTeal, .nexusBlue, .yellow]

        for i in 0..<8 {
            let angle = Double(i) * (360.0 / 8.0) * .pi / 180
            let distance: CGFloat = 60

            let particle = Particle(
                id: i,
                x: centerX,
                y: centerY,
                scale: 0.5,
                opacity: 1.0,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement()!
            )
            particles.append(particle)

            let endX = centerX + CGFloat(cos(angle)) * distance
            let endY = centerY + CGFloat(sin(angle)) * distance

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

private struct Particle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
    var color: Color
}

// MARK: - Preview

#Preview {
    TasksView()
        .preferredColorScheme(.dark)
}
