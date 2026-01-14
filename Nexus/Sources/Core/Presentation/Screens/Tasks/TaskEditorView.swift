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

    // MARK: - Initialization

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

    // MARK: - Body

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
            .toolbar { toolbarContent }
            .onAppear { handleOnAppear() }
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

// MARK: - Toolbar

private extension TaskEditorView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") { saveTask() }
                .fontWeight(.semibold)
                .disabled(title.isEmpty)
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
                    notesPlaceholder
                }
        } header: {
            Text("Notes")
        }
    }

    @ViewBuilder
    var notesPlaceholder: some View {
        if notes.isEmpty {
            Text("Add notes...")
                .font(.nexusBody)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    var urlSection: some View {
        Section {
            HStack(spacing: 12) {
                urlIcon
                urlTextField
                urlClearButton
            }
        }
    }

    var urlIcon: some View {
        Image(systemName: "link")
            .font(.system(size: 16))
            .foregroundStyle(url.isEmpty ? Color.gray.opacity(0.5) : Color.nexusBlue)
            .frame(width: 24)
    }

    var urlTextField: some View {
        TextField("Add URL or link", text: $url)
            .font(.nexusBody)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .url)
    }

    @ViewBuilder
    var urlClearButton: some View {
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

    var prioritySection: some View {
        Section {
            Picker("Priority", selection: $priority) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    priorityOption(priority)
                }
            }
        }
    }

    func priorityOption(_ priority: TaskPriority) -> some View {
        HStack {
            Circle()
                .fill(colorForPriority(priority))
                .frame(width: 8, height: 8)
            Text(priority.rawValue.capitalized)
        }
        .tag(priority)
    }

    var projectSection: some View {
        Section {
            HStack {
                Text("Project")
                Spacer()
                projectMenu
            }
        }
    }

    var projectMenu: some View {
        Menu {
            projectMenuItems
        } label: {
            projectMenuLabel
        }
    }

    @ViewBuilder
    var projectMenuItems: some View {
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
    }

    var projectMenuLabel: some View {
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

    var assigneesSection: some View {
        Section {
            Button {
                showPeoplePicker = true
            } label: {
                assigneesRow
            }
            .buttonStyle(.plain)
        }
    }

    var assigneesRow: some View {
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

    var dueDateSection: some View {
        Section {
            Toggle("Due Date", isOn: $hasDueDate.animation())
                .onChange(of: hasDueDate) { _, newValue in
                    if newValue, dueDate == nil {
                        dueDate = Date()
                    }
                }

            if hasDueDate {
                dueDatePicker
            }
        }
    }

    var dueDatePicker: some View {
        DatePicker(
            "Date",
            selection: Binding(
                get: { dueDate ?? Date() },
                set: { dueDate = $0 }
            ),
            displayedComponents: [.date]
        )
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
                reminderPicker
            }
        }
    }

    var reminderPicker: some View {
        DatePicker(
            "Remind at",
            selection: Binding(
                get: { reminderDate ?? Date() },
                set: { reminderDate = $0 }
            ),
            displayedComponents: [.date, .hourAndMinute]
        )
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

// MARK: - Assignee Avatars

private extension TaskEditorView {
    var selectedAssignees: [PersonModel] {
        allPeople.filter { selectedAssigneeIds.contains($0.id) }
    }

    var assigneeAvatars: some View {
        HStack(spacing: -8) {
            ForEach(Array(selectedAssignees.prefix(3))) { person in
                personAvatar(person, size: 28)
            }

            if selectedAssignees.count > 3 {
                overflowBadge
            }
        }
    }

    func personAvatar(_ person: PersonModel, size: CGFloat) -> some View {
        let avatarColor = Color(hex: person.colorHex) ?? .nexusPurple

        return Text(person.initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(avatarColor))
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: avatarColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    var overflowBadge: some View {
        let overflowCount = selectedAssignees.count - 3
        let displayText = overflowCount > 99 ? "+99" : "+\(overflowCount)"

        return Text(displayText)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
            )
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

// MARK: - Helpers

private extension TaskEditorView {
    static var lastUsedProjectId: UUID? {
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

    func colorForPriority(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: .secondary
        case .medium: .nexusBlue
        case .high: .nexusOrange
        case .urgent: .nexusRed
        }
    }

    func handleOnAppear() {
        if task == nil {
            focusedField = .title
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
            updateExistingTask(existingTask, dueDate: finalDueDate, reminder: finalReminder, group: selectedGroup, assignees: assignees)
            taskToSchedule = existingTask
        } else {
            taskToSchedule = createNewTask(dueDate: finalDueDate, reminder: finalReminder, group: selectedGroup, assignees: assignees)
        }

        scheduleReminderIfNeeded(for: taskToSchedule, reminder: finalReminder)
        dismiss()
    }

    func updateExistingTask(_ existingTask: TaskModel, dueDate: Date?, reminder: Date?, group: TaskGroupModel?, assignees: [PersonModel]) {
        existingTask.title = title
        existingTask.notes = notes
        existingTask.url = url.isEmpty ? nil : url
        existingTask.priority = priority
        existingTask.dueDate = dueDate
        existingTask.reminderDate = reminder
        existingTask.group = group
        existingTask.assignees = assignees.isEmpty ? nil : assignees
        existingTask.updatedAt = .now
    }

    func createNewTask(dueDate: Date?, reminder: Date?, group: TaskGroupModel?, assignees: [PersonModel]) -> TaskModel {
        let newTask = TaskModel(
            title: title,
            notes: notes,
            url: url.isEmpty ? nil : url,
            priority: priority,
            dueDate: dueDate,
            reminderDate: reminder,
            group: group,
            assignees: assignees.isEmpty ? nil : assignees
        )
        modelContext.insert(newTask)
        return newTask
    }

    func scheduleReminderIfNeeded(for task: TaskModel, reminder: Date?) {
        if reminder != nil {
            Task {
                let notificationService = DefaultTaskNotificationService.shared
                let granted = await notificationService.requestAuthorization()
                if granted {
                    await notificationService.scheduleReminder(for: task)
                }
            }
        } else {
            DefaultTaskNotificationService.shared.cancelReminder(for: task)
        }
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

    @State private var showContactsPicker = false
    @State private var contactsAccessDenied = false
    @State private var searchText = ""
    @State private var viewingTasksForPerson: PersonModel?

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    importFromContactsSection
                }

                if allPeople.isEmpty {
                    emptyState
                } else {
                    peopleList
                }
            }
            .searchable(text: $searchText, prompt: "Search people")
            .navigationTitle("Assignees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showContactsPicker) {
                ContactsPickerView(
                    existingContactIds: existingContactIdentifiers,
                    onSelect: { contacts in
                        importContacts(contacts)
                    }
                )
            }
            .sheet(item: $viewingTasksForPerson) { person in
                PersonTasksView(person: person)
            }
            .alert("Contacts Access Denied", isPresented: $contactsAccessDenied) {
                Button("Open Settings") { openSettings() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Contacts access in Settings to import people from your contacts.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - PeoplePickerSheet Toolbar

private extension PeoplePickerSheet {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
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

// MARK: - PeoplePickerSheet Content

private extension PeoplePickerSheet {
    var importFromContactsSection: some View {
        Section {
            Button {
                requestContactsAccess()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.nexusBlue)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Contacts")
                            .font(.nexusSubheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Add people from your address book")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    var filteredPeople: [PersonModel] {
        if searchText.isEmpty {
            return allPeople
        }
        return allPeople.filter { person in
            person.name.localizedCaseInsensitiveContains(searchText) ||
            person.email?.localizedCaseInsensitiveContains(searchText) == true ||
            person.phone?.contains(searchText) == true
        }
    }

    var peopleList: some View {
        Section {
            ForEach(filteredPeople) { person in
                personRow(person)
            }
            .onDelete(perform: deletePeople)
        } header: {
            if !allPeople.isEmpty {
                Text("People")
            }
        }
    }

    var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.2")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("No People Yet")
                    .font(.nexusHeadline)

                Text("Import from Contacts or add manually")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                addPersonButton
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .listRowBackground(Color.clear)
    }

    var addPersonButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onAddNew()
            }
        } label: {
            Label("Add Manually", systemImage: "plus")
                .font(.nexusSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.nexusPurple))
        }
    }

    func personRow(_ person: PersonModel) -> some View {
        HStack(spacing: 12) {
            personAvatar(person)
            personInfo(person)
            Spacer()
            selectionIndicator(person)
        }
        .contentShape(Rectangle())
        .contextMenu {
            personContextMenu(person)
        }
        .onTapGesture {
            toggleSelection(person)
        }
    }

    func personAvatar(_ person: PersonModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(person.initials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(hex: person.colorHex) ?? .nexusPurple))

            if person.isLinkedToContact {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.nexusBlue)
                    .background(
                        Circle()
                            .fill(Color.nexusSurface)
                            .frame(width: 16, height: 16)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }

    func personInfo(_ person: PersonModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(person.name)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if person.isLinkedToContact {
                    Text("Contacts")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.nexusBlue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.nexusBlue.opacity(0.15))
                        )
                }
            }

            if let email = person.email, !email.isEmpty {
                Text(email)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            } else if let phone = person.phone, !phone.isEmpty {
                Text(phone)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func selectionIndicator(_ person: PersonModel) -> some View {
        let isSelected = selectedIds.contains(person.id)

        return ZStack {
            Circle()
                .strokeBorder(Color.nexusBorder, lineWidth: 2)
                .frame(width: 22, height: 22)
                .opacity(isSelected ? 0 : 1)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.nexusGreen)
                .scaleEffect(isSelected ? 1 : 0.5)
                .opacity(isSelected ? 1 : 0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }

    @ViewBuilder
    func personContextMenu(_ person: PersonModel) -> some View {
        Button {
            toggleSelection(person)
        } label: {
            if selectedIds.contains(person.id) {
                Label("Deselect", systemImage: "minus.circle")
            } else {
                Label("Select", systemImage: "checkmark.circle")
            }
        }

        Button {
            viewingTasksForPerson = person
        } label: {
            Label("View Assigned Tasks", systemImage: "checklist")
        }

        Divider()

        Button(role: .destructive) {
            deletePerson(person)
        } label: {
            Label("Delete Person", systemImage: "trash")
        }
    }
}

// MARK: - PeoplePickerSheet Actions

private extension PeoplePickerSheet {
    var existingContactIdentifiers: Set<String> {
        Set(allPeople.compactMap { $0.contactIdentifier })
    }

    func toggleSelection(_ person: PersonModel) {
        let isCurrentlySelected = selectedIds.contains(person.id)

        if isCurrentlySelected {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isCurrentlySelected {
                selectedIds.remove(person.id)
            } else {
                selectedIds.insert(person.id)
            }
        }
    }

    func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            let person = allPeople[index]
            selectedIds.remove(person.id)
            modelContext.delete(person)
        }
    }

    func deletePerson(_ person: PersonModel) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        selectedIds.remove(person.id)
        modelContext.delete(person)
    }

    func requestContactsAccess() {
        Task {
            let status = await ContactsService.requestAccess()
            await MainActor.run {
                switch status {
                case .authorized:
                    showContactsPicker = true
                case .denied, .restricted:
                    contactsAccessDenied = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    func importContacts(_ contacts: [ImportedContact]) {
        for contact in contacts {
            let person = PersonModel(
                name: contact.name,
                email: contact.email,
                phone: contact.phone,
                colorHex: PersonModel.defaultColors.randomElement() ?? "#8B5CF6",
                contactIdentifier: contact.identifier
            )
            modelContext.insert(person)
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    TaskEditorView(task: nil)
        .preferredColorScheme(.dark)
}
