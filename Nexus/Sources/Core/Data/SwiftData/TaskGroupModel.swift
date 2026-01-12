import Foundation
import SwiftData

@Model
final class TaskGroupModel {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder.fill"
    var colorHex: String = "#8B5CF6"
    var order: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \TaskModel.group)
    var tasks: [TaskModel]?

    init(
        id: UUID = UUID(),
        name: String = "",
        icon: String = "folder.fill",
        colorHex: String = "#8B5CF6",
        order: Int = 0,
        createdAt: Date = .now,
        tasks: [TaskModel]? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.createdAt = createdAt
        self.tasks = tasks
    }

    var activeTaskCount: Int {
        tasks?.filter { !$0.isCompleted }.count ?? 0
    }
}

extension TaskGroupModel {
    static let defaultIcons = [
        "folder.fill",
        "star.fill",
        "heart.fill",
        "briefcase.fill",
        "house.fill",
        "person.fill",
        "cart.fill",
        "book.fill",
        "lightbulb.fill",
        "hammer.fill",
        "flag.fill",
        "target",
        "trophy.fill",
        "gift.fill",
        "airplane",
        "graduationcap.fill"
    ]

    static let defaultColors = [
        "#8B5CF6", // Purple
        "#3B82F6", // Blue
        "#14B8A6", // Teal
        "#22C55E", // Green
        "#F59E0B", // Orange
        "#EF4444", // Red
        "#EC4899", // Pink
        "#6366F1", // Indigo
    ]
}
