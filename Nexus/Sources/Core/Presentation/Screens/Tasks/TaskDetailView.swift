import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let task: TaskModel

    @State private var showEditor = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                headerSection
                detailsSection
                if !task.notes.isEmpty {
                    notesSection
                }
                if let url = task.url, !url.isEmpty {
                    linkSection(url)
                }
                if let assignees = task.assignees, !assignees.isEmpty {
                    assigneesSection(assignees)
                }
                metadataSection
            }
            .listStyle(.insetGrouped)
            .background(Color.nexusBackground)
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showEditor) {
                TaskEditorView(task: task)
            }
        }
    }
}

// MARK: - Toolbar

private extension TaskDetailView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showEditor = true
            } label: {
                Text("Edit").fontWeight(.medium)
            }
        }
    }
}

// MARK: - Header Section

private extension TaskDetailView {
    var headerSection: some View {
        Section {
            HStack(spacing: DesignSystem.Spacing.sm) {
                completionIndicator
                VStack(alignment: .leading, spacing: 6) {
                    titleText
                    statusRow
                }
                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(headerAccessibilityLabel)
        }
    }

    var completionIndicator: some View {
        ZStack {
            if task.isCompleted {
                Circle()
                    .fill(Color.nexusGreen)
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.nexusCaption.weight(.bold))
                    .foregroundStyle(Color.nexusOnAccent)
            } else {
                Circle()
                    .strokeBorder(priorityColor, lineWidth: 3)
                    .frame(width: 32, height: 32)
            }
        }
        .accessibilityHidden(true)
    }

    var titleText: some View {
        Text(task.title)
            .font(.nexusTitle3)
            .fontWeight(.semibold)
            .strikethrough(task.isCompleted, color: .secondary)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
    }

    var statusRow: some View {
        HStack(spacing: 8) {
            priorityBadge
            if task.isCompleted { completedBadge }
        }
    }

    var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon)
                .font(.nexusCaption2.weight(.semibold))
            Text(task.priority.rawValue.capitalized)
                .font(.nexusCaption2.weight(.medium))
        }
        .foregroundStyle(priorityColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(priorityColor.opacity(0.12)))
        .accessibilityLabel("\(task.priority.rawValue.capitalized) priority")
    }

    var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.nexusCaption2.weight(.semibold))
            Text("Completed")
                .font(.nexusCaption2.weight(.medium))
        }
        .foregroundStyle(Color.nexusGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.nexusGreen.opacity(0.12)))
        .accessibilityLabel("Completed")
    }

    var headerAccessibilityLabel: String {
        let status = task.isCompleted ? "Completed" : "\(task.priority.rawValue.capitalized) priority"
        return "\(task.title), \(status)"
    }
}

// MARK: - Details Section

private extension TaskDetailView {
    var detailsSection: some View {
        Section("Details") {
            if let dueDate = task.dueDate {
                LabeledContent {
                    Text(formatDate(dueDate))
                        .font(.nexusSubheadline)
                        .foregroundStyle(dueDateColor(dueDate))
                } label: {
                    Label("Due Date", systemImage: "calendar")
                        .foregroundStyle(dueDateColor(dueDate))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Due Date: \(formatDate(dueDate))")
            }

            if let reminderDate = task.reminderDate {
                LabeledContent {
                    Text(formatDateTime(reminderDate))
                        .font(.nexusSubheadline)
                } label: {
                    Label("Reminder", systemImage: "bell.fill")
                        .foregroundStyle(Color.nexusPurple)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Reminder: \(formatDateTime(reminderDate))")
            }

            if let group = task.group {
                LabeledContent {
                    Text(group.name)
                        .font(.nexusSubheadline)
                } label: {
                    Label(
                        "Project",
                        systemImage: group.icon
                    )
                    .foregroundStyle(Color(hex: group.colorHex))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Project: \(group.name)")
            } else {
                LabeledContent {
                    Text("Inbox")
                        .font(.nexusSubheadline)
                } label: {
                    Label("Project", systemImage: "tray.fill")
                        .foregroundStyle(Color.nexusBlue)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Project: Inbox")
            }
        }
    }
}

// MARK: - Notes Section

private extension TaskDetailView {
    var notesSection: some View {
        Section("Notes") {
            Text(task.notes)
                .font(.nexusBody)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Notes: \(task.notes)")
        }
    }
}

// MARK: - Link Section

private extension TaskDetailView {
    func linkSection(_ urlString: String) -> some View {
        Section("Link") {
            Button {
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "link")
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusBlue)
                        .frame(width: DesignSystem.Size.Icon.lg)
                        .accessibilityHidden(true)

                    Text(urlString)
                        .font(.nexusSubheadline)
                        .foregroundStyle(Color.nexusBlue)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.nexusCaption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Open link: \(urlString)")
            .accessibilityAddTraits(.isLink)
        }
    }
}

// MARK: - Assignees Section

private extension TaskDetailView {
    func assigneesSection(_ assignees: [PersonModel]) -> some View {
        Section("Assignees") {
            ForEach(assignees) { person in
                assigneeRow(person)
            }
        }
    }

    func assigneeRow(_ person: PersonModel) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            personAvatar(person)
            personInfo(person)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(personAccessibilityLabel(person))
    }

    func personAvatar(_ person: PersonModel) -> some View {
        Text(person.initials)
            .font(.nexusFootnote.weight(.semibold))
            .foregroundStyle(Color.nexusOnAccent)
            .frame(width: DesignSystem.Size.Avatar.sm + 8, height: DesignSystem.Size.Avatar.sm + 8)
            .background(Circle().fill(Color(hex: person.colorHex)))
            .accessibilityHidden(true)
    }

    func personInfo(_ person: PersonModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(person.name)
                    .font(.nexusSubheadline.weight(.medium))

                if person.isLinkedToContact {
                    Text("Contacts")
                        .font(.nexusCaption2.weight(.medium))
                        .foregroundStyle(Color.nexusBlue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.nexusBlue.opacity(0.15)))
                        .accessibilityLabel("linked to Contacts")
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

    func personAccessibilityLabel(_ person: PersonModel) -> String {
        var parts = [person.name]
        if let email = person.email, !email.isEmpty { parts.append(email) }
        else if let phone = person.phone, !phone.isEmpty { parts.append(phone) }
        if person.isLinkedToContact { parts.append("linked to Contacts") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Metadata Section

private extension TaskDetailView {
    var metadataSection: some View {
        Section {
            LabeledContent("Created", value: formatDateTime(task.createdAt))
                .font(.nexusCaption)
                .foregroundStyle(.tertiary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Created: \(formatDateTime(task.createdAt))")

            LabeledContent("Updated", value: formatDateTime(task.updatedAt))
                .font(.nexusCaption)
                .foregroundStyle(.tertiary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Updated: \(formatDateTime(task.updatedAt))")

            if let completedAt = task.completedAt {
                LabeledContent("Completed", value: formatDateTime(completedAt))
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Completed: \(formatDateTime(completedAt))")
            }
        }
    }
}

// MARK: - Helper Properties

private extension TaskDetailView {
    var priorityColor: Color {
        switch task.priority {
        case .urgent: .nexusRed
        case .high: .nexusOrange
        case .medium: .nexusBlue
        case .low: .secondary
        }
    }

    var priorityIcon: String {
        switch task.priority {
        case .urgent: "flame.fill"
        case .high: "flag.fill"
        case .medium: "flag"
        case .low: "flag"
        }
    }

    func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) {
            return .nexusOrange
        } else if date < Date() && !task.isCompleted {
            return .nexusRed
        }
        return .secondary
    }

    func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        if date < Date() {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return days == 1 ? "1 day overdue" : "\(days) days overdue"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    func formatDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(task: TaskModel(title: "Sample Task", notes: "Some notes here", priority: .high))
}
