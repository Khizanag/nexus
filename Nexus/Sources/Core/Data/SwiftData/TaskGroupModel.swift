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
        // Row 1 - Reds & Pinks
        "#EF4444", // Red
        "#F43F5E", // Rose
        "#EC4899", // Pink
        "#D946EF", // Fuchsia
        // Row 2 - Purples & Blues
        "#A855F7", // Violet
        "#8B5CF6", // Purple
        "#6366F1", // Indigo
        "#3B82F6", // Blue
        // Row 3 - Cyans & Greens
        "#0EA5E9", // Sky Blue
        "#06B6D4", // Cyan
        "#14B8A6", // Teal
        "#10B981", // Emerald
        // Row 4 - Greens & Warm
        "#22C55E", // Green
        "#84CC16", // Lime
        "#F59E0B", // Amber
        "#F97316", // Orange
    ]
}
