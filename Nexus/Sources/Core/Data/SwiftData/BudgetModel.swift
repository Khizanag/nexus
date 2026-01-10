import Foundation
import SwiftData

@Model
final class BudgetModel {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var currency: String = "GEL"
    var category: TransactionCategory = TransactionCategory.other
    var period: BudgetPeriod = BudgetPeriod.monthly
    var startDate: Date = Date()
    var isActive: Bool = true
    var colorHex: String = "8B5CF6"
    var icon: String = "dollarsign.circle.fill"
    var rolloverEnabled: Bool = false
    var rolloverAmount: Double = 0
    var alertThreshold: Double = 0.8
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PlannedExpenseModel.budget)
    var plannedExpenses: [PlannedExpenseModel]?

    init(
        id: UUID = UUID(),
        name: String = "",
        amount: Double = 0,
        currency: String = "USD",
        category: TransactionCategory = .other,
        period: BudgetPeriod = .monthly,
        startDate: Date = .now,
        isActive: Bool = true,
        colorHex: String = "8B5CF6",
        icon: String = "dollarsign.circle.fill",
        rolloverEnabled: Bool = false,
        rolloverAmount: Double = 0,
        alertThreshold: Double = 0.8,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currency = currency
        self.category = category
        self.period = period
        self.startDate = startDate
        self.isActive = isActive
        self.colorHex = colorHex
        self.icon = icon
        self.rolloverEnabled = rolloverEnabled
        self.rolloverAmount = rolloverAmount
        self.alertThreshold = alertThreshold
        self.createdAt = createdAt
    }

    var effectiveBudget: Double {
        amount + (rolloverEnabled ? rolloverAmount : 0)
    }

    var currentPeriodStart: Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .yearly:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
    }

    var currentPeriodEnd: Date {
        let calendar = Calendar.current

        switch period {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: currentPeriodStart)?.addingTimeInterval(-1) ?? currentPeriodStart
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: currentPeriodStart)?.addingTimeInterval(-1) ?? currentPeriodStart
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: currentPeriodStart)?.addingTimeInterval(-1) ?? currentPeriodStart
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: currentPeriodStart)?.addingTimeInterval(-1) ?? currentPeriodStart
        }
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: Date(), to: currentPeriodEnd).day ?? 0
    }

    var periodProgress: Double {
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: currentPeriodStart, to: currentPeriodEnd).day ?? 1
        let elapsedDays = calendar.dateComponents([.day], from: currentPeriodStart, to: Date()).day ?? 0
        return Double(elapsedDays) / Double(max(totalDays, 1))
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var shortName: String {
        switch self {
        case .daily: "Day"
        case .weekly: "Week"
        case .monthly: "Month"
        case .yearly: "Year"
        }
    }
}

enum BudgetStatus {
    case onTrack
    case warning
    case exceeded
    case completed

    var color: String {
        switch self {
        case .onTrack: "green"
        case .warning: "orange"
        case .exceeded: "red"
        case .completed: "blue"
        }
    }

    var icon: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .exceeded: "xmark.circle.fill"
        case .completed: "flag.checkered"
        }
    }

    var message: String {
        switch self {
        case .onTrack: "On Track"
        case .warning: "Approaching Limit"
        case .exceeded: "Over Budget"
        case .completed: "Period Complete"
        }
    }
}
