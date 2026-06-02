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
    @State private var recentlyChangedTask: TaskModel?
    @State private var taskIsLeaving = false
    @State private var showGroupEditor = false
    @State private var editingGroup: TaskGroupModel?
    @State private var collapsedGroups: Set<UUID> = []
    @State private var searchText = ""
    @State private var toggleTrigger = false
    @State private var lightTrigger = false
    @State private var mediumTrigger = false

    private let inboxId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                taskList
                toastOverlay
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search tasks")
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
            .sensoryFeedback(.impact(weight: .medium), trigger: toggleTrigger)
            .sensoryFeedback(.impact(weight: .light), trigger: lightTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: mediumTrigger)
        }
    }
}

// MARK: - Main List

private extension TasksView {
    var taskList: some View {
        List {
            filterPicker
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
                .listRowSeparator(.hidden)

            if searchResults.isEmpty && !searchText.isEmpty {
                searchEmptyRow
            } else if searchResults.isEmpty {
                mainEmptyRow
            } else {
                taskSections
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.nexusBackground)
    }

    @ViewBuilder
    var taskSections: some View {
        if groupingMode == .project && selectedFilter == .all && searchText.isEmpty {
            projectSections
        } else if selectedFilter == .all && searchText.isEmpty {
            switch groupingMode {
            case .dueDate:
                ForEach(groupByDueDate(filteredTasks), id: \.0) { title, tasks in
                    namedSection(title: title, tasks: tasks)
                }
            case .priority:
                ForEach(groupByPriority(filteredTasks), id: \.0) { title, tasks in
                    namedSection(title: title, tasks: tasks)
                }
            case .none, .project:
                flatTasksSection(filteredTasks)
            }
        } else {
            flatTasksSection(searchResults)
        }
    }

    @ViewBuilder
    var projectSections: some View {
        ForEach(taskGroups) { group in
            let tasks = filteredTasks.filter { $0.group?.id == group.id }
            if !tasks.isEmpty {
                projectSection(group: group, tasks: tasks)
            }
        }
        let inboxTasks = filteredTasks.filter { $0.group == nil }
        if !inboxTasks.isEmpty {
            inboxSection(tasks: inboxTasks)
        }
    }

    func namedSection(title: String, tasks: [TaskModel]) -> some View {
        Section(header: sectionHeaderLabel(title, count: tasks.count)) {
            ForEach(tasks) { task in
                taskRow(task)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        completeSwipeAction(task)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteSwipeAction(task)
                    }
            }
        }
    }

    func flatTasksSection(_ tasks: [TaskModel]) -> some View {
        Section {
            ForEach(tasks) { task in
                taskRow(task)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        completeSwipeAction(task)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteSwipeAction(task)
                    }
            }
        }
    }

    func projectSection(group: TaskGroupModel, tasks: [TaskModel]) -> some View {
        let isExpanded = Binding(
            get: { !collapsedGroups.contains(group.id) },
            set: { expanded in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expanded {
                        collapsedGroups.remove(group.id)
                    } else {
                        collapsedGroups.insert(group.id)
                    }
                }
            }
        )
        let groupColor = Color(hex: group.colorHex)

        return Section(
            isExpanded: isExpanded,
            content: {
                ForEach(tasks) { task in
                    taskRow(task)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            completeSwipeAction(task)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteSwipeAction(task)
                        }
                }
            },
            header: {
                projectSectionHeader(group: group, tasks: tasks, color: groupColor)
            }
        )
    }

    func inboxSection(tasks: [TaskModel]) -> some View {
        let isExpanded = Binding(
            get: { !collapsedGroups.contains(inboxId) },
            set: { expanded in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expanded {
                        collapsedGroups.remove(inboxId)
                    } else {
                        collapsedGroups.insert(inboxId)
                    }
                }
            }
        )

        return Section(
            isExpanded: isExpanded,
            content: {
                ForEach(tasks) { task in
                    taskRow(task)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            completeSwipeAction(task)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteSwipeAction(task)
                        }
                }
            },
            header: {
                inboxSectionHeader(tasks: tasks)
            }
        )
    }

    var searchEmptyRow: some View {
        ContentUnavailableView.search(text: searchText)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    var mainEmptyRow: some View {
        ContentUnavailableView(
            emptyStateTitle,
            systemImage: selectedFilter == .completed ? "checkmark.circle" : "checklist",
            description: Text(emptyStateSubtitle)
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Section Headers

private extension TasksView {
    func sectionHeaderLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.nexusCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text("\(count)")
                .font(.nexusCaption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, DesignSystem.Spacing.xxs + 2)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.nexusBorder))
        }
        .padding(.horizontal, DesignSystem.Spacing.xxs)
    }

    func projectSectionHeader(group: TaskGroupModel, tasks: [TaskModel], color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: DesignSystem.Size.Icon.badge, height: DesignSystem.Size.Icon.badge)
                Image(systemName: group.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.nexusHeadline)
                    .foregroundStyle(.primary)
                Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
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
        .accessibilityLabel("\(group.name), \(tasks.count) task\(tasks.count == 1 ? "" : "s")")
    }

    func inboxSectionHeader(tasks: [TaskModel]) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.nexusBlue.opacity(0.15))
                    .frame(width: DesignSystem.Size.Icon.badge, height: DesignSystem.Size.Icon.badge)
                Image(systemName: "tray.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.nexusBlue)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Inbox")
                    .font(.nexusHeadline)
                    .foregroundStyle(.primary)
                Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityLabel("Inbox, \(tasks.count) task\(tasks.count == 1 ? "" : "s")")
    }
}

// MARK: - Swipe Actions

private extension TasksView {
    func completeSwipeAction(_ task: TaskModel) -> some View {
        Button {
            toggleTask(task)
        } label: {
            Label(
                task.isCompleted ? "Restore" : "Complete",
                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
            )
        }
        .tint(task.isCompleted ? Color.nexusOrange : Color.nexusGreen)
    }

    func deleteSwipeAction(_ task: TaskModel) -> some View {
        Button(role: .destructive) {
            deleteTask(task)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Filter Picker

private extension TasksView {
    var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(TaskFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Task Row

private extension TasksView {
    func taskRow(_ task: TaskModel) -> some View {
        Button {
            viewingTask = task
        } label: {
            TaskRow(
                task: task,
                isRecentlyChanged: recentlyChangedTaskId == task.id,
                isLeaving: taskIsLeaving && recentlyChangedTaskId == task.id,
                onToggle: { toggleTask(task) }
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(for: task))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: DesignSystem.Spacing.xxs,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.xxs,
            trailing: DesignSystem.Spacing.md
        ))
        .contextMenu {
            taskContextMenu(task)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(task))
        .accessibilityValue(task.isCompleted ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to view details")
    }

    func rowBackground(for task: TaskModel) -> some View {
        let highlight = task.isCompleted ? Color.nexusGreen : Color.nexusOrange
        let isChanged = recentlyChangedTaskId == task.id
        return RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
            .fill(isChanged ? highlight.opacity(0.08) : Color.nexusSurface)
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .strokeBorder(
                        isChanged ? highlight.opacity(0.4) : priorityAccentColor(for: task).opacity(task.isCompleted ? 0 : 0.15),
                        lineWidth: isChanged ? 1.5 : 1
                    )
            }
    }

    func rowAccessibilityLabel(_ task: TaskModel) -> String {
        var parts = [task.title]
        if !task.notes.isEmpty { parts.append(task.notes) }
        if let due = task.dueDate {
            parts.append("Due \(due.formatted(.dateTime.month(.abbreviated).day()))")
        }
        if task.priority == .urgent { parts.append("Urgent priority") }
        else if task.priority == .high { parts.append("High priority") }
        return parts.joined(separator: ", ")
    }

    func priorityAccentColor(for task: TaskModel) -> Color {
        switch task.priority {
        case .urgent: Color.nexusRed
        case .high: Color.nexusOrange
        case .medium: Color.nexusBlue
        case .low: Color.nexusTextTertiary
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

// MARK: - Toast

private extension TasksView {
    @ViewBuilder
    var toastOverlay: some View {
        if let message = toastMessage {
            statusToast(message: message, isCompletion: toastIsCompletion)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
                .zIndex(100)
        }
    }

    func statusToast(message: String, isCompletion: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            toastIcon(isCompletion: isCompletion)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(isCompletion ? "Completed" : "Restored")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            undoButton(isCompletion: isCompletion)
        }
        .padding(.leading, DesignSystem.Spacing.md)
        .padding(.trailing, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .glassBackground(
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous),
            tint: isCompletion ? Color.nexusGreen : Color.nexusOrange
        )
    }

    func toastIcon(isCompletion: Bool) -> some View {
        Image(systemName: isCompletion ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
            .font(.title2)
            .foregroundStyle(isCompletion ? Color.nexusGreen : Color.nexusOrange)
    }

    func undoButton(isCompletion: Bool) -> some View {
        Button {
            undoTaskChange()
        } label: {
            Text("Undo")
                .font(.nexusSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.nexusOnAccent)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isCompletion ? Color.nexusGreen : Color.nexusOrange)
                )
        }
        .buttonStyle(.plain)
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
        .buttonStyle(.glass)
        .accessibilityLabel("Filter and group options")
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
        .buttonStyle(.glass)
        .accessibilityLabel("New task")
    }
}

// MARK: - Computed Properties

private extension TasksView {
    var filteredTasks: [TaskModel] {
        let base: [TaskModel]
        switch selectedFilter {
        case .all:
            base = allTasks.filter { !$0.isCompleted }
        case .today:
            base = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInToday(dueDate) && !task.isCompleted
            }
        case .upcoming:
            base = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate > Date() && !task.isCompleted
            }
        case .completed:
            base = allTasks.filter { $0.isCompleted }
        }
        return sortTasks(base)
    }

    var searchResults: [TaskModel] {
        guard !searchText.isEmpty else { return filteredTasks }
        return filteredTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchText) ||
            task.notes.localizedCaseInsensitiveContains(searchText)
        }
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

// MARK: - Actions

private extension TasksView {
    func deleteGroup(_ group: TaskGroupModel) {
        withAnimation(.spring(response: 0.3)) {
            modelContext.delete(group)
        }
    }

    func toggleTask(_ task: TaskModel) {
        let wasCompleted = task.isCompleted
        let taskTitle = task.title

        toggleTrigger.toggle()
        recentlyChangedTaskId = task.id
        recentlyChangedTask = task
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.spring(response: 0.4)) {
                if recentlyChangedTaskId == task.id {
                    toastMessage = nil
                    recentlyChangedTaskId = nil
                    recentlyChangedTask = nil
                    taskIsLeaving = false
                }
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.spring(response: 0.4)) {
                if recentlyChangedTaskId == task.id {
                    toastMessage = nil
                    recentlyChangedTaskId = nil
                    recentlyChangedTask = nil
                    taskIsLeaving = false
                }
            }
        }

        if task.reminderDate != nil {
            Task {
                await DefaultTaskNotificationService.shared.scheduleReminder(for: task)
            }
        }
    }

    func undoTaskChange() {
        guard let task = recentlyChangedTask else { return }

        mediumTrigger.toggle()

        withAnimation(.spring(response: 0.4)) {
            toastMessage = nil
            recentlyChangedTaskId = nil
            recentlyChangedTask = nil
            taskIsLeaving = false
        }

        if task.isCompleted {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                task.isCompleted = false
                task.completedAt = nil
                task.updatedAt = .now
            }
            if task.reminderDate != nil {
                Task {
                    await DefaultTaskNotificationService.shared.scheduleReminder(for: task)
                }
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                task.isCompleted = true
                task.completedAt = .now
                task.updatedAt = .now
            }
            DefaultTaskNotificationService.shared.cancelReminder(for: task)
        }
    }

    func duplicateTask(_ task: TaskModel) {
        lightTrigger.toggle()

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
        lightTrigger.toggle()

        withAnimation(.spring(response: 0.3)) {
            task.priority = priority
            task.updatedAt = .now
        }
    }

    func moveToProject(_ task: TaskModel, project: TaskGroupModel?) {
        lightTrigger.toggle()

        withAnimation(.spring(response: 0.3)) {
            task.group = project
            task.updatedAt = .now
        }
    }

    func deleteTask(_ task: TaskModel) {
        mediumTrigger.toggle()

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
        case .completed: "Done"
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var checkmarkScale: CGFloat = 1.0
    @State private var showCelebration = false
    @State private var showStrikethrough = false

    var body: some View {
        HStack(spacing: 0) {
            priorityBar
            contentRow
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        .scaleEffect(isLeaving ? 0.92 : (isRecentlyChanged ? 1.02 : 1.0))
        .opacity(isLeaving ? 0.6 : 1.0)
        .offset(y: isLeaving ? (task.isCompleted ? 8 : -8) : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7),
            value: isRecentlyChanged
        )
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.75),
            value: isLeaving
        )
        .overlay(alignment: .center) { celebrationOverlay }
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
            .padding(.vertical, DesignSystem.Spacing.xs)
            .accessibilityHidden(true)
    }

    var contentRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            checkmarkButton
            taskContent
            Spacer(minLength: DesignSystem.Spacing.xs)
            trailingContent
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.md)
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
        .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        .accessibilityAddTraits(.isButton)
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs + 2) {
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
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: showStrikethrough)
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
            HStack(spacing: DesignSystem.Spacing.xs) {
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
        HStack(spacing: DesignSystem.Spacing.xs) {
            if isLeaving {
                Image(systemName: task.isCompleted ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(highlightColor.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }

            if task.priority == .urgent {
                priorityIcon(icon: "flame.fill", color: .nexusRed)
            } else if task.priority == .high {
                priorityIcon(icon: "flag.fill", color: .nexusOrange)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    func priorityIcon(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .opacity(task.isCompleted ? 0.4 : 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    var celebrationOverlay: some View {
        if showCelebration, task.isCompleted, !reduceMotion {
            CelebrationParticles()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: dueDateIcon(dueDate))
                .font(.system(size: 10, weight: .semibold))
            Text(formatDueDate(dueDate))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(dueDateColor(dueDate))
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background { Capsule().fill(dueDateColor(dueDate).opacity(0.12)) }
        .opacity(task.isCompleted ? 0.5 : 1)
        .accessibilityLabel("Due \(formatDueDate(dueDate))")
    }

    var reminderBadge: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.nexusPurple)
            .padding(.horizontal, DesignSystem.Spacing.xxs + 2)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background { Capsule().fill(Color.nexusPurple.opacity(0.12)) }
            .opacity(task.isCompleted ? 0.5 : 1)
            .accessibilityLabel("Reminder set")
    }

    var urlBadge: some View {
        Image(systemName: "link")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.nexusBlue)
            .padding(.horizontal, DesignSystem.Spacing.xxs + 2)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background { Capsule().fill(Color.nexusBlue.opacity(0.12)) }
            .opacity(task.isCompleted ? 0.5 : 1)
            .accessibilityLabel("Has link")
    }

    func assigneesBadge(_ assignees: [PersonModel]) -> some View {
        HStack(spacing: -4) {
            ForEach(Array(assignees.prefix(2))) { person in
                let avatarColor = Color(hex: person.colorHex)
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
        .accessibilityLabel(assigneesAccessibilityLabel(assignees))
    }

    func assigneesAccessibilityLabel(_ assignees: [PersonModel]) -> String {
        let names = assignees.prefix(2).map { $0.initials }.joined(separator: ", ")
        if assignees.count > 2 {
            return "\(names) and \(assignees.count - 2) more"
        }
        return names
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
        if Calendar.current.isDateInToday(date) { return "sun.max.fill" }
        if date < Date() { return "exclamationmark.circle.fill" }
        if Calendar.current.isDateInTomorrow(date) { return "sunrise.fill" }
        return "calendar"
    }

    func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) { return .nexusOrange }
        if date < Date() { return .nexusRed }
        return .secondary
    }
}

// MARK: - TaskRow Actions

private extension TaskRow {
    func handleToggle() {
        if !task.isCompleted {
            withAnimation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.4)) {
                checkmarkScale = 1.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.5)) {
                    checkmarkScale = 1.0
                }
            }
            if !reduceMotion {
                showCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showStrikethrough = true
                }
            } else {
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
        .accessibilityHidden(true)
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
}
