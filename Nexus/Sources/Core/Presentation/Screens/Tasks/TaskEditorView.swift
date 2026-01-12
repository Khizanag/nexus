import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskGroupModel.order) private var taskGroups: [TaskGroupModel]

    let task: TaskModel?

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var hasReminder: Bool
    @State private var reminderDate: Date?
    @State private var selectedGroupId: UUID?
    @State private var showNewProject = false

    @FocusState private var isTitleFocused: Bool

    private static let lastUsedProjectKey = "lastUsedProjectId"

    init(task: TaskModel?) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _priority = State(initialValue: task?.priority ?? .medium)
        _dueDate = State(initialValue: task?.dueDate)
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _hasReminder = State(initialValue: task?.reminderDate != nil)
        _reminderDate = State(initialValue: task?.reminderDate)
        _selectedGroupId = State(initialValue: task?.group?.id ?? Self.lastUsedProjectId)
    }

    private static var lastUsedProjectId: UUID? {
        get {
            guard let uuidString = UserDefaults.standard.string(forKey: lastUsedProjectKey) else {
                return nil
            }
            return UUID(uuidString: uuidString)
        }
        set {
            if let uuid = newValue {
                UserDefaults.standard.set(uuid.uuidString, forKey: lastUsedProjectKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastUsedProjectKey)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .font(.nexusHeadline)
                        .focused($isTitleFocused)

                    TextField("Notes", text: $notes, axis: .vertical)
                        .font(.nexusBody)
                        .lineLimit(3...6)
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(colorForPriority(priority))
                                    .frame(width: 8, height: 8)
                                Text(priority.rawValue.capitalized)
                            }
                            .tag(priority)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Project")
                        Spacer()
                        Menu {
                            Button {
                                selectedGroupId = nil
                            } label: {
                                Label("Inbox", systemImage: selectedGroupId == nil ? "checkmark" : "tray.fill")
                            }

                            ForEach(taskGroups) { group in
                                Button {
                                    selectedGroupId = group.id
                                } label: {
                                    Label(
                                        group.name,
                                        systemImage: selectedGroupId == group.id ? "checkmark" : group.icon
                                    )
                                }
                            }

                            Divider()

                            Button {
                                showNewProject = true
                            } label: {
                                Label("New Project", systemImage: "plus.circle")
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if let groupId = selectedGroupId,
                                   let group = taskGroups.first(where: { $0.id == groupId }) {
                                    Image(systemName: group.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: group.colorHex) ?? Color.nexusPurple)
                                    Text(group.name)
                                        .foregroundStyle(.primary)
                                } else {
                                    Image(systemName: "tray.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.nexusBlue)
                                    Text("Inbox")
                                        .foregroundStyle(.primary)
                                }
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }

                Section {
                    Toggle("Reminder", isOn: $hasReminder.animation())

                    if hasReminder {
                        DatePicker(
                            "Remind at",
                            selection: Binding(
                                get: { reminderDate ?? Date() },
                                set: { reminderDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                if task != nil {
                    Section {
                        Button(role: .destructive) {
                            deleteTask()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Task")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if task == nil {
                    isTitleFocused = true
                }
            }
            .sheet(isPresented: $showNewProject) {
                TaskGroupEditorView(group: nil)
            }
        }
    }

    private func colorForPriority(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: .secondary
        case .medium: .nexusBlue
        case .high: .nexusOrange
        case .urgent: .nexusRed
        }
    }

    private func saveTask() {
        let finalDueDate = hasDueDate ? dueDate : nil
        let finalReminder = hasReminder ? reminderDate : nil
        let selectedGroup = taskGroups.first { $0.id == selectedGroupId }

        // Cache the selected project for next task creation
        Self.lastUsedProjectId = selectedGroupId

        let taskToSchedule: TaskModel

        if let existingTask = task {
            existingTask.title = title
            existingTask.notes = notes
            existingTask.priority = priority
            existingTask.dueDate = finalDueDate
            existingTask.reminderDate = finalReminder
            existingTask.group = selectedGroup
            existingTask.updatedAt = .now
            taskToSchedule = existingTask
        } else {
            let newTask = TaskModel(
                title: title,
                notes: notes,
                priority: priority,
                dueDate: finalDueDate,
                reminderDate: finalReminder,
                group: selectedGroup
            )
            modelContext.insert(newTask)
            taskToSchedule = newTask
        }

        if finalReminder != nil {
            Task {
                let notificationService = DefaultTaskNotificationService.shared
                let granted = await notificationService.requestAuthorization()
                if granted {
                    await notificationService.scheduleReminder(for: taskToSchedule)
                }
            }
        } else {
            DefaultTaskNotificationService.shared.cancelReminder(for: taskToSchedule)
        }

        dismiss()
    }

    private func deleteTask() {
        if let task {
            DefaultTaskNotificationService.shared.cancelReminder(for: task)
            modelContext.delete(task)
        }
        dismiss()
    }
}

#Preview {
    TaskEditorView(task: nil)
        .preferredColorScheme(.dark)
}
