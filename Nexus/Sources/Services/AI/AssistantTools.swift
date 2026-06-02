import Foundation
import FoundationModels

// Tools the on-device model can call to read and act on the user's data.
// Each is Sendable (it only holds the Sendable NexusStore actor) so the
// framework can invoke them concurrently.

// MARK: - Create Task

struct CreateTaskTool: Tool {
    let name = "createTask"
    let description = "Create a to-do task in the user's task list."
    let store: NexusStore

    @Generable
    struct Arguments {
        @Guide(description: "Short imperative task title")
        var title: String
        @Guide(description: "Priority level", .anyOf(["low", "medium", "high", "urgent"]))
        var priority: String
        @Guide(description: "Days from today until due; omit if none, 0 for today, 1 for tomorrow")
        var dueInDays: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let priority = TaskPriority(rawValue: arguments.priority) ?? .medium
        let dueDate = arguments.dueInDays.flatMap { days in
            Calendar.current
                .date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: .now))?
                .addingTimeInterval(12 * 3600)
        }
        return try await store.createTask(title: arguments.title, priority: priority, dueDate: dueDate)
    }
}

// MARK: - Create Note

struct CreateNoteTool: Tool {
    let name = "createNote"
    let description = "Save a note for the user."
    let store: NexusStore

    @Generable
    struct Arguments {
        @Guide(description: "A short note title")
        var title: String
        @Guide(description: "The note body; may be empty")
        var body: String
    }

    func call(arguments: Arguments) async throws -> String {
        try await store.createNote(title: arguments.title, body: arguments.body)
    }
}

// MARK: - Log Health

struct LogHealthTool: Tool {
    let name = "logHealth"
    let description = "Log a health metric such as weight, water, sleep, steps, calories, heart rate, or mood."
    let store: NexusStore

    @Generable
    struct Arguments {
        @Guide(
            description: "Metric to log",
            .anyOf(["weight", "waterIntake", "sleep", "steps", "calories", "heartRate", "mood", "energy"])
        )
        var metric: String
        @Guide(description: "Value in the metric's natural unit (kg, ml, hours, steps, kcal, bpm, or 1-10)")
        var value: Double
    }

    func call(arguments: Arguments) async throws -> String {
        let metric = HealthMetricType(rawValue: arguments.metric) ?? .weight
        return try await store.logHealth(metric: metric, value: arguments.value)
    }
}

// MARK: - Query Finance

struct QueryFinanceTool: Tool {
    let name = "queryFinance"
    let description = "Summarize the user's income and spending for a recent time window. Use this instead of guessing numbers."
    let store: NexusStore

    @Generable
    struct Arguments {
        @Guide(description: "Time window", .anyOf(["week", "month", "year"]))
        var period: String
    }

    func call(arguments: Arguments) async throws -> String {
        let period = FinancePeriod(rawValue: arguments.period) ?? .month
        return try await store.financeSummary(period: period)
    }
}

// MARK: - Query Tasks

struct QueryTasksTool: Tool {
    let name = "queryTasks"
    let description = "Look up the user's current tasks, including how many are pending, due today, or overdue."
    let store: NexusStore

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        try await store.tasksOverview()
    }
}
