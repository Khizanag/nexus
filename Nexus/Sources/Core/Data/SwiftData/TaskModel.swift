import Foundation
import SwiftData

@Model
final class TaskModel {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var url: String?
    var isCompleted: Bool = false
    var priority: TaskPriority = TaskPriority.medium
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var reminderDate: Date?

    @Relationship(deleteRule: .nullify, inverse: \TagModel.tasks)
    var tags: [TagModel]?

    @Relationship(deleteRule: .cascade)
    var subtasks: [SubtaskModel]?

    @Relationship
    var group: TaskGroupModel?

    @Relationship(deleteRule: .nullify)
    var assignees: [PersonModel]?

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        url: String? = nil,
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        reminderDate: Date? = nil,
        tags: [TagModel]? = nil,
        subtasks: [SubtaskModel]? = nil,
        group: TaskGroupModel? = nil,
        assignees: [PersonModel]? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.url = url
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reminderDate = reminderDate
        self.tags = tags
        self.subtasks = subtasks
        self.group = group
        self.assignees = assignees
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case urgent

    var color: String {
        switch self {
        case .low: "gray"
        case .medium: "blue"
        case .high: "orange"
        case .urgent: "red"
        }
    }

    var sortOrder: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        case .urgent: 4
        }
    }
}

@Model
final class SubtaskModel {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var order: Int = 0

    @Relationship
    var parent: TaskModel?

    init(
        id: UUID = UUID(),
        title: String = "",
        isCompleted: Bool = false,
        order: Int = 0,
        parent: TaskModel? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.order = order
        self.parent = parent
    }
}
