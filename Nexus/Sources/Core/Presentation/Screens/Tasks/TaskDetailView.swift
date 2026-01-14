import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let task: TaskModel

    @State private var showEditor = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                .padding(20)
            }
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
                Text("Edit")
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Header Section

private extension TaskDetailView {
    var headerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                completionIndicator
                VStack(alignment: .leading, spacing: 6) {
                    titleText
                    statusRow
                }
                Spacer()
            }
        }
        .padding(20)
        .background { sectionBackground }
    }

    var completionIndicator: some View {
        ZStack {
            if task.isCompleted {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.nexusGreen, Color.nexusGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(priorityColor, lineWidth: 3)
                    .frame(width: 32, height: 32)
            }
        }
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
            if task.isCompleted {
                completedBadge
            }
        }
    }

    var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(task.priority.rawValue.capitalized)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(priorityColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(priorityColor.opacity(0.12)))
    }

    var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Completed")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.nexusGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.nexusGreen.opacity(0.12)))
    }
}

// MARK: - Details Section

private extension TaskDetailView {
    var detailsSection: some View {
        VStack(spacing: 0) {
            if let dueDate = task.dueDate {
                detailRow(
                    icon: "calendar",
                    title: "Due Date",
                    value: formatDate(dueDate),
                    color: dueDateColor(dueDate)
                )
                Divider().padding(.leading, 52)
            }

            if let reminderDate = task.reminderDate {
                detailRow(
                    icon: "bell.fill",
                    title: "Reminder",
                    value: formatDateTime(reminderDate),
                    color: .nexusPurple
                )
                Divider().padding(.leading, 52)
            }

            if let group = task.group {
                detailRow(
                    icon: group.icon,
                    title: "Project",
                    value: group.name,
                    color: Color(hex: group.colorHex) ?? .nexusPurple
                )
            } else {
                detailRow(
                    icon: "tray.fill",
                    title: "Project",
                    value: "Inbox",
                    color: .nexusBlue
                )
            }
        }
        .background { sectionBackground }
    }

    func detailRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Notes Section

private extension TaskDetailView {
    var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Notes")

            Text(task.notes)
                .font(.nexusBody)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background { sectionBackground }
        }
    }
}

// MARK: - Link Section

private extension TaskDetailView {
    func linkSection(_ urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Link")

            Button {
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.nexusBlue)
                        .frame(width: 32)

                    Text(urlString)
                        .font(.nexusSubheadline)
                        .foregroundStyle(Color.nexusBlue)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background { sectionBackground }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Assignees Section

private extension TaskDetailView {
    func assigneesSection(_ assignees: [PersonModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Assignees")

            VStack(spacing: 0) {
                ForEach(Array(assignees.enumerated()), id: \.element.id) { index, person in
                    assigneeRow(person)

                    if index < assignees.count - 1 {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .background { sectionBackground }
        }
    }

    func assigneeRow(_ person: PersonModel) -> some View {
        HStack(spacing: 14) {
            personAvatar(person)
            personInfo(person)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    func personAvatar(_ person: PersonModel) -> some View {
        Text(person.initials)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color(hex: person.colorHex) ?? .nexusPurple))
    }

    func personInfo(_ person: PersonModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(person.name)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)

                if person.isLinkedToContact {
                    Text("Contacts")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.nexusBlue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.nexusBlue.opacity(0.15)))
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
}

// MARK: - Metadata Section

private extension TaskDetailView {
    var metadataSection: some View {
        VStack(spacing: 8) {
            metadataRow("Created", date: task.createdAt)
            metadataRow("Updated", date: task.updatedAt)
            if let completedAt = task.completedAt {
                metadataRow("Completed", date: completedAt)
            }
        }
        .padding(.top, 8)
    }

    func metadataRow(_ label: String, date: Date) -> some View {
        HStack {
            Text(label)
                .font(.nexusCaption)
                .foregroundStyle(.tertiary)

            Spacer()

            Text(formatDateTime(date))
                .font(.nexusCaption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Helper Views

private extension TaskDetailView {
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.nexusCaption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.nexusSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.nexusBorder, lineWidth: 1)
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
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < Date() {
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
        .preferredColorScheme(.dark)
}
