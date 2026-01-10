import Foundation
import SwiftData

@Model
final class NoteModel {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    var isFavorite: Bool = false
    var color: String?

    @Relationship(deleteRule: .nullify, inverse: \TagModel.notes)
    var tags: [TagModel]?

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        color: String? = nil,
        tags: [TagModel]? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.color = color
        self.tags = tags
    }
}
