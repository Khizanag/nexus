import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]
    @Query(sort: \TaskGroupModel.order) private var taskGroups: [TaskGroupModel]

    @State private var selectedFilter: TaskFilter = .all
    @State private var groupingMode: TaskGrouping = .project
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
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(groupColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: group.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(groupColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
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
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(groupColor.opacity(0.2), lineWidth: 1)
                        }
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

            if !isCollapsed && !tasks.isEmpty {
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
    let isRecentlyChanged: Bool
    let isLeaving: Bool
    let onToggle: () -> Void

    @State private var checkmarkScale: CGFloat = 1.0
    @State private var showCelebration = false
    @State private var strikethroughProgress: CGFloat = 0

    private var highlightColor: Color {
        task.isCompleted ? Color.nexusGreen : Color.nexusOrange
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if !task.isCompleted {
                    // Animate checkmark bounce
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                        checkmarkScale = 1.4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                            checkmarkScale = 1.0
                        }
                    }
                    // Show celebration particles
                    showCelebration = true
                    // Animate strikethrough - make it slower and more visible
                    withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                        strikethroughProgress = 1.0
                    }
                }
                onToggle()
            }) {
                ZStack {
                    // Base circle
                    Circle()
                        .strokeBorder(task.isCompleted ? Color.nexusGreen : priorityColor, lineWidth: 2)
                        .frame(width: 26, height: 26)

                    // Filled circle when completed
                    if task.isCompleted {
                        Circle()
                            .fill(Color.nexusGreen)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(checkmarkScale)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.nexusBody)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .overlay(alignment: .leading) {
                        if task.isCompleted || (isRecentlyChanged && strikethroughProgress > 0) {
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.secondary)
                                    .frame(
                                        width: geo.size.width * (isRecentlyChanged ? strikethroughProgress : 1),
                                        height: 1.5
                                    )
                                    .offset(y: geo.size.height / 2)
                            }
                        }
                    }

                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.nexusCaption)
                    }
                    .foregroundStyle(dueDateColor(dueDate))
                    .opacity(task.isCompleted ? 0.6 : 1)
                }
            }

            Spacer()

            // Direction indicator when leaving
            if isLeaving {
                Image(systemName: task.isCompleted ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(highlightColor.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
            }

            if task.priority == .high || task.priority == .urgent {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(priorityColor)
                    .opacity(task.isCompleted ? 0.4 : 1)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isRecentlyChanged ? highlightColor.opacity(0.12) : Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isRecentlyChanged ? highlightColor.opacity(0.5) : Color.nexusBorder,
                            lineWidth: isRecentlyChanged ? 2 : 1
                        )
                }
        }
        .overlay {
            // Celebration particles for completion
            if showCelebration && task.isCompleted {
                CelebrationParticles()
                    .allowsHitTesting(false)
            }
        }
        // Transition effect - scale down and fade when leaving
        .scaleEffect(isLeaving ? 0.92 : (isRecentlyChanged ? 1.02 : 1.0))
        .opacity(isLeaving ? 0.6 : 1.0)
        .offset(y: isLeaving ? (task.isCompleted ? 8 : -8) : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRecentlyChanged)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: isLeaving)
        .onChange(of: task.isCompleted) { oldValue, newValue in
            if !newValue {
                // Reset animation states when uncompleted
                strikethroughProgress = 0
                showCelebration = false
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
