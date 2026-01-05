import Foundation
import SwiftData

@Model
final class TaskModel {
    var id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var priority: TaskPriority
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var reminderDate: Date?

    @Relationship(deleteRule: .nullify, inverse: \TagModel.tasks)
    var tags: [TagModel]

    @Relationship(deleteRule: .cascade)
    var subtasks: [SubtaskModel]

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        reminderDate: Date? = nil,
        tags: [TagModel] = [],
        subtasks: [SubtaskModel] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reminderDate = reminderDate
        self.tags = tags
        self.subtasks = subtasks
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
}

@Model
final class SubtaskModel {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var order: Int

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
