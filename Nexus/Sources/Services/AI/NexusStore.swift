import Foundation
import SwiftData

/// Off-main-actor gateway the assistant's tools use to read and mutate app data.
/// `@ModelActor` makes it Sendable and gives it its own `ModelContext`, so tool
/// calls (which may run concurrently) never touch the main context.
@ModelActor
actor NexusStore {

    // MARK: - Writes

    func createTask(title: String, priority: TaskPriority, dueDate: Date?) throws -> String {
        let task = TaskModel(title: title, priority: priority, dueDate: dueDate)
        modelContext.insert(task)
        try modelContext.save()

        var detail = "Added “\(title)” to your tasks"
        if priority != .medium { detail += " (\(priority.rawValue) priority)" }
        if let dueDate { detail += ", due \(Self.dateString(dueDate))" }
        return detail + "."
    }

    func createNote(title: String, body: String) throws -> String {
        let note = NoteModel(title: title, content: body)
        modelContext.insert(note)
        try modelContext.save()
        return "Saved a note titled “\(title)”."
    }

    func logHealth(metric: HealthMetricType, value: Double) throws -> String {
        let entry = HealthEntryModel(type: metric, value: value, unit: metric.defaultUnit, date: .now)
        modelContext.insert(entry)
        try modelContext.save()
        return "Logged \(Self.number(value)) \(metric.defaultUnit) of \(metric.displayName.lowercased())."
    }

    // MARK: - Reads

    func tasksOverview() throws -> String {
        let all = try modelContext.fetch(FetchDescriptor<TaskModel>())
        let pending = all.filter { !$0.isCompleted }
        let today = pending.filter { isToday($0.dueDate) }
        let overdue = pending.filter { isOverdue($0.dueDate) }

        if all.isEmpty { return "There are no tasks yet." }
        var parts = ["\(pending.count) pending"]
        if !today.isEmpty { parts.append("\(today.count) due today") }
        if !overdue.isEmpty { parts.append("\(overdue.count) overdue") }
        let titles = pending.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        return parts.joined(separator: ", ") + ".\n" + titles
    }

    func financeSummary(period: FinancePeriod) throws -> String {
        let start = period.startDate
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.date >= start }
        )
        let transactions = try modelContext.fetch(descriptor)
        guard !transactions.isEmpty else { return "No transactions recorded for this \(period.rawValue)." }

        let income = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let currency = transactions.first?.currency ?? "USD"

        let byCategory = Dictionary(grouping: transactions.filter { $0.type == .expense }) { $0.category }
        let top = byCategory
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .max { $0.total < $1.total }

        var summary = "This \(period.rawValue): income \(Self.money(income, currency)), "
        summary += "spending \(Self.money(expense, currency)), net \(Self.money(income - expense, currency))."
        if let top { summary += " Top category: \(top.category.rawValue) (\(Self.money(top.total, currency)))." }
        return summary
    }

    // MARK: - Helpers

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func isOverdue(_ date: Date?) -> Bool {
        guard let date else { return false }
        return date < .now && !Calendar.current.isDateInToday(date)
    }

    private static func dateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private static func number(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private static func money(_ value: Double, _ currency: String) -> String {
        value.formatted(.currency(code: currency).precision(.fractionLength(0)))
    }
}

// MARK: - Finance Period

enum FinancePeriod: String, Sendable {
    case week
    case month
    case year

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date.now
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month: return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year: return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }
}
