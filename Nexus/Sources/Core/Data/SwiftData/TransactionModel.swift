import Foundation
import SwiftData

@Model
final class TransactionModel {
    var id: UUID = UUID()
    var amount: Double = 0
    var currency: String = "GEL"
    var title: String = ""
    var notes: String = ""
    var category: TransactionCategory = TransactionCategory.other
    var type: TransactionType = TransactionType.expense
    var date: Date = Date()
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \TagModel.transactions)
    var tags: [TagModel]?

    init(
        id: UUID = UUID(),
        amount: Double = 0,
        currency: String = "USD",
        title: String = "",
        notes: String = "",
        category: TransactionCategory = .other,
        type: TransactionType = .expense,
        date: Date = .now,
        createdAt: Date = .now,
        tags: [TagModel]? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.title = title
        self.notes = notes
        self.category = category
        self.type = type
        self.date = date
        self.createdAt = createdAt
        self.tags = tags
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    case transfer
}

enum TransactionCategory: String, Codable, CaseIterable {
    case food
    case transport
    case shopping
    case entertainment
    case health
    case utilities
    case housing
    case education
    case travel
    case salary
    case investment
    case gift
    case other

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .shopping: "bag.fill"
        case .entertainment: "gamecontroller.fill"
        case .health: "heart.fill"
        case .utilities: "bolt.fill"
        case .housing: "house.fill"
        case .education: "book.fill"
        case .travel: "airplane"
        case .salary: "briefcase.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .gift: "gift.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .food: "orange"
        case .transport: "blue"
        case .shopping: "pink"
        case .entertainment: "purple"
        case .health: "red"
        case .utilities: "yellow"
        case .housing: "brown"
        case .education: "indigo"
        case .travel: "teal"
        case .salary: "green"
        case .investment: "mint"
        case .gift: "cyan"
        case .other: "gray"
        }
    }
}
