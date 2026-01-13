import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskGroupModel.order) private var taskGroups: [TaskGroupModel]
    @Query(sort: \PersonModel.name) private var allPeople: [PersonModel]

    let task: TaskModel?

    @State private var title: String
    @State private var notes: String
    @State private var url: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var hasReminder: Bool
    @State private var reminderDate: Date?
    @State private var selectedGroupId: UUID?
    @State private var selectedAssigneeIds: Set<UUID>
    @State private var showNewProject = false
    @State private var showNewPerson = false
    @State private var showPeoplePicker = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case title, notes, url
    }

    private static let lastUsedProjectKey = "lastUsedProjectId"

    init(task: TaskModel?) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _url = State(initialValue: task?.url ?? "")
        _priority = State(initialValue: task?.priority ?? .medium)
        _dueDate = State(initialValue: task?.dueDate)
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _hasReminder = State(initialValue: task?.reminderDate != nil)
        _reminderDate = State(initialValue: task?.reminderDate)
        _selectedGroupId = State(initialValue: task?.group?.id ?? Self.lastUsedProjectId)
        _selectedAssigneeIds = State(initialValue: Set(task?.assignees?.map { $0.id } ?? []))
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

    private var selectedAssignees: [PersonModel] {
        allPeople.filter { selectedAssigneeIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                notesSection
                urlSection
                prioritySection
                projectSection
                assigneesSection
                dueDateSection
                reminderSection

                if task != nil {
                    deleteSection
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
                    focusedField = .title
                }
            }
            .sheet(isPresented: $showNewProject) {
                TaskGroupEditorView(group: nil)
            }
            .sheet(isPresented: $showNewPerson) {
                PersonEditorView(person: nil)
            }
            .sheet(isPresented: $showPeoplePicker) {
                PeoplePickerSheet(
                    selectedIds: $selectedAssigneeIds,
                    onAddNew: { showNewPerson = true }
                )
            }
        }
    }
}

// MARK: - Form Sections

private extension TaskEditorView {
    var titleSection: some View {
        Section {
            TextField("Task title", text: $title)
                .font(.nexusHeadline)
                .focused($focusedField, equals: .title)
        }
    }

    var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .font(.nexusBody)
                .frame(minHeight: 80, maxHeight: 200)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .notes)
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Add notes...")
                            .font(.nexusBody)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
        } header: {
            Text("Notes")
        }
    }

    var urlSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundStyle(url.isEmpty ? Color.gray.opacity(0.5) : Color.nexusBlue)
                    .frame(width: 24)

                TextField("Add URL or link", text: $url)
                    .font(.nexusBody)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .url)

                if !url.isEmpty {
                    Button {
                        url = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var prioritySection: some View {
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
    }

    var projectSection: some View {
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
    }

    var assigneesSection: some View {
        Section {
            Button {
                showPeoplePicker = true
            } label: {
                HStack {
                    Text("Assignees")
                        .foregroundStyle(.primary)

                    Spacer()

                    if selectedAssignees.isEmpty {
                        Text("None")
                            .foregroundStyle(.secondary)
                    } else {
                        assigneeAvatars
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    var assigneeAvatars: some View {
        HStack(spacing: -8) {
            ForEach(Array(selectedAssignees.prefix(3))) { person in
                personAvatar(person, size: 28)
            }

            if selectedAssignees.count > 3 {
                Text("+\(selectedAssignees.count - 3)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.nexusSurface))
                    .overlay(Circle().strokeBorder(Color.nexusBorder, lineWidth: 2))
            }
        }
    }

    func personAvatar(_ person: PersonModel, size: CGFloat) -> some View {
        Text(person.initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: person.colorHex) ?? .nexusPurple))
            .overlay(Circle().strokeBorder(Color.nexusBackground, lineWidth: 2))
    }

    var dueDateSection: some View {
        Section {
            Toggle("Due Date", isOn: $hasDueDate.animation())
                .onChange(of: hasDueDate) { _, newValue in
                    if newValue, dueDate == nil {
                        dueDate = Date()
                    }
                }

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
    }

    var reminderSection: some View {
        Section {
            Toggle("Reminder", isOn: $hasReminder.animation())
                .onChange(of: hasReminder) { _, newValue in
                    if newValue, reminderDate == nil {
                        reminderDate = Date()
                    }
                }

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
    }

    var deleteSection: some View {
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

// MARK: - Helpers

private extension TaskEditorView {
    func colorForPriority(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: .secondary
        case .medium: .nexusBlue
        case .high: .nexusOrange
        case .urgent: .nexusRed
        }
    }
}

// MARK: - Actions

private extension TaskEditorView {
    func saveTask() {
        let finalDueDate = hasDueDate ? dueDate : nil
        let finalReminder = hasReminder ? reminderDate : nil
        let selectedGroup = taskGroups.first { $0.id == selectedGroupId }
        let assignees = allPeople.filter { selectedAssigneeIds.contains($0.id) }

        Self.lastUsedProjectId = selectedGroupId

        let taskToSchedule: TaskModel

        if let existingTask = task {
            existingTask.title = title
            existingTask.notes = notes
            existingTask.url = url.isEmpty ? nil : url
            existingTask.priority = priority
            existingTask.dueDate = finalDueDate
            existingTask.reminderDate = finalReminder
            existingTask.group = selectedGroup
            existingTask.assignees = assignees.isEmpty ? nil : assignees
            existingTask.updatedAt = .now
            taskToSchedule = existingTask
        } else {
            let newTask = TaskModel(
                title: title,
                notes: notes,
                url: url.isEmpty ? nil : url,
                priority: priority,
                dueDate: finalDueDate,
                reminderDate: finalReminder,
                group: selectedGroup,
                assignees: assignees.isEmpty ? nil : assignees
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

    func deleteTask() {
        if let task {
            DefaultTaskNotificationService.shared.cancelReminder(for: task)
            modelContext.delete(task)
        }
        dismiss()
    }
}

// MARK: - People Picker Sheet

struct PeoplePickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PersonModel.name) private var allPeople: [PersonModel]

    @Binding var selectedIds: Set<UUID>
    let onAddNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if allPeople.isEmpty {
                    emptyState
                } else {
                    ForEach(allPeople) { person in
                        personRow(person)
                    }
                    .onDelete(perform: deletePeople)
                }
            }
            .navigationTitle("Assignees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAddNew()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No People Yet")
                .font(.nexusHeadline)

            Text("Add people to assign them to tasks")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAddNew()
                }
            } label: {
                Label("Add Person", systemImage: "plus")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.nexusPurple))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }

    private func personRow(_ person: PersonModel) -> some View {
        Button {
            if selectedIds.contains(person.id) {
                selectedIds.remove(person.id)
            } else {
                selectedIds.insert(person.id)
            }
        } label: {
            HStack(spacing: 12) {
                Text(person.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: person.colorHex) ?? .nexusPurple))

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let email = person.email, !email.isEmpty {
                        Text(email)
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if selectedIds.contains(person.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.nexusGreen)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            let person = allPeople[index]
            selectedIds.remove(person.id)
            modelContext.delete(person)
        }
    }
}

#Preview {
    TaskEditorView(task: nil)
        .preferredColorScheme(.dark)
}
