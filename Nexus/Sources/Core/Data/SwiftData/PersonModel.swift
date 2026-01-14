import Foundation
import SwiftData

@Model
final class PersonModel {
    var id: UUID = UUID()
    var name: String = ""
    var email: String?
    var phone: String?
    var colorHex: String = "#8B5CF6"
    var createdAt: Date = Date()
    var contactIdentifier: String?

    @Relationship(deleteRule: .nullify, inverse: \TaskModel.assignees)
    var tasks: [TaskModel]?

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String? = nil,
        phone: String? = nil,
        colorHex: String = "#8B5CF6",
        createdAt: Date = .now,
        contactIdentifier: String? = nil,
        tasks: [TaskModel]? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.contactIdentifier = contactIdentifier
        self.tasks = tasks
    }

    var isLinkedToContact: Bool {
        contactIdentifier != nil
    }

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

extension PersonModel {
    static let defaultColors = [
        "#EF4444", // Red
        "#F97316", // Orange
        "#F59E0B", // Amber
        "#22C55E", // Green
        "#14B8A6", // Teal
        "#0EA5E9", // Sky Blue
        "#3B82F6", // Blue
        "#6366F1", // Indigo
        "#8B5CF6", // Purple
        "#A855F7", // Violet
        "#EC4899", // Pink
        "#F43F5E", // Rose
    ]
}
