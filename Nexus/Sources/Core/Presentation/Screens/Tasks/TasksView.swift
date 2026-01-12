import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var allTasks: [TaskModel]

    @State private var selectedFilter: TaskFilter = .all
    @State private var groupingMode: TaskGrouping = .dueDate
    @State private var showNewTask = false
    @State private var selectedTask: TaskModel?
    @State private var completedTaskMessage: String?
    @State private var recentlyCompletedTaskId: UUID?

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

    private var groupedTasks: [(String, [TaskModel])] {
        guard selectedFilter == .all else {
            return [("", filteredTasks)]
        }

        switch groupingMode {
        case .none:
            return [("", filteredTasks)]
        case .dueDate:
            return groupByDueDate(filteredTasks)
        case .priority:
            return groupByPriority(filteredTasks)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    filterBar

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedTasks, id: \.0) { group in
                                if !group.0.isEmpty {
                                    taskGroupSection(title: group.0, tasks: group.1)
                                } else {
                                    ForEach(group.1) { task in
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

                // Completion toast
                if let message = completedTaskMessage {
                    VStack {
                        Spacer()
                        completedToast(message: message)
                            .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
    private func taskRowView(_ task: TaskModel) -> some View {
        TaskRow(
            task: task,
            isRecentlyCompleted: recentlyCompletedTaskId == task.id,
            onToggle: {
                toggleTask(task)
            }
        )
        .onTapGesture {
            selectedTask = task
        }
    }

    private func completedToast(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.nexusGreen)

            Text(message)
                .font(.nexusSubheadline)
                .fontWeight(.medium)

            Spacer()

            Text("Moved to Completed")
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
                        .strokeBorder(Color.nexusGreen.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
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

        if !wasCompleted {
            // Mark as recently completed for animation
            recentlyCompletedTaskId = task.id

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Show completion animation for longer
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                task.isCompleted = true
                task.completedAt = .now
                task.updatedAt = .now
            }

            // Show toast after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4)) {
                    completedTaskMessage = task.title
                }
            }

            // Hide toast and remove from list after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.spring(response: 0.4)) {
                    completedTaskMessage = nil
                    recentlyCompletedTaskId = nil
                }
            }

            DefaultTaskNotificationService.shared.cancelReminder(for: task)
        } else {
            // Uncomplete task
            withAnimation(.spring(response: 0.3)) {
                task.isCompleted = false
                task.completedAt = nil
                task.updatedAt = .now
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
    case none, dueDate, priority

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .dueDate: "Due Date"
        case .priority: "Priority"
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
    let isRecentlyCompleted: Bool
    let onToggle: () -> Void

    @State private var checkmarkScale: CGFloat = 1.0
    @State private var showCelebration = false
    @State private var strikethroughProgress: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if !task.isCompleted {
                    // Animate checkmark
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        checkmarkScale = 1.3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            checkmarkScale = 1.0
                        }
                    }
                    // Show celebration
                    showCelebration = true
                    // Animate strikethrough
                    withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
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
                        if task.isCompleted || isRecentlyCompleted {
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.secondary)
                                    .frame(width: geo.size.width * (isRecentlyCompleted ? strikethroughProgress : 1), height: 1.5)
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
                .fill(isRecentlyCompleted ? Color.nexusGreen.opacity(0.1) : Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isRecentlyCompleted ? Color.nexusGreen.opacity(0.4) : Color.nexusBorder,
                            lineWidth: isRecentlyCompleted ? 2 : 1
                        )
                }
        }
        .overlay {
            // Celebration particles
            if showCelebration {
                CelebrationParticles()
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(isRecentlyCompleted ? 0.98 : 1.0)
        .opacity(isRecentlyCompleted ? 0.9 : 1.0)
        .animation(.spring(response: 0.5), value: isRecentlyCompleted)
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
