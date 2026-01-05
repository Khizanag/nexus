import Foundation
import SwiftData

@Model
final class ChatMessageModel {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        role: String = "user",
        content: String = "",
        timestamp: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
