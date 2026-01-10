import Foundation
import SwiftData

@Model
final class TagModel {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "gray"
    var createdAt: Date = Date()

    var notes: [NoteModel]?
    var tasks: [TaskModel]?
    var transactions: [TransactionModel]?

    init(
        id: UUID = UUID(),
        name: String = "",
        color: String = "gray",
        createdAt: Date = .now,
        notes: [NoteModel]? = nil,
        tasks: [TaskModel]? = nil,
        transactions: [TransactionModel]? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.notes = notes
        self.tasks = tasks
        self.transactions = transactions
    }
}
