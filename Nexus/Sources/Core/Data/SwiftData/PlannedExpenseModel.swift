import Foundation
import SwiftData

@Model
final class PlannedExpenseModel {
    var id: UUID
    var name: String
    var amount: Double
    var icon: String
    var isRecurring: Bool
    var isPaid: Bool
    var paidDate: Date?
    var notes: String
    var budget: BudgetModel?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        amount: Double = 0,
        icon: String = "dollarsign.circle.fill",
        isRecurring: Bool = true,
        isPaid: Bool = false,
        paidDate: Date? = nil,
        notes: String = "",
        budget: BudgetModel? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.icon = icon
        self.isRecurring = isRecurring
        self.isPaid = isPaid
        self.paidDate = paidDate
        self.notes = notes
        self.budget = budget
        self.createdAt = createdAt
    }
}
