import Foundation
import FoundationModels

/// The assistant engine. Prefers the on-device Foundation Models LLM (streaming,
/// tool-calling). When Apple Intelligence is unavailable (older device, disabled,
/// or still downloading — including most simulators) it degrades to a small,
/// honest command handler so the assistant stays useful.
@MainActor
@Observable
final class NexusAssistant {
    enum Mode: Equatable {
        case foundationModels
        case fallback(reason: String)
    }

    let mode: Mode
    private(set) var isResponding = false

    private let store: NexusStore
    private var session: LanguageModelSession?
    private let fallback: CommandFallback

    init(store: NexusStore) {
        self.store = store
        self.fallback = CommandFallback(store: store)

        switch SystemLanguageModel.default.availability {
        case .available:
            mode = .foundationModels
            let session = Self.makeSession(store: store)
            session.prewarm()
            self.session = session
        case .unavailable(let reason):
            mode = .fallback(reason: Self.describe(reason))
            self.session = nil
        }
    }

    /// Non-nil when running without the on-device model — shown as a one-time note.
    var fallbackNotice: String? {
        if case .fallback(let reason) = mode { return reason }
        return nil
    }

    // MARK: - Sending

    /// Streams a reply, calling `onPartial` with each cumulative snapshot, and returns the final text.
    func send(_ prompt: String, onPartial: @escaping (String) -> Void) async -> String {
        isResponding = true
        defer { isResponding = false }

        guard let session else {
            let reply = await fallback.reply(to: prompt)
            onPartial(reply)
            return reply
        }

        do {
            var latest = ""
            for try await partial in session.streamResponse(to: prompt) {
                latest = partial.content
                onPartial(partial.content)
            }
            return latest
        } catch let error as LanguageModelSession.GenerationError {
            return handle(error)
        } catch {
            return "Something went wrong. Please try again."
        }
    }

    // MARK: - Session lifecycle

    private static func makeSession(store: NexusStore) -> LanguageModelSession {
        LanguageModelSession(
            tools: [
                CreateTaskTool(store: store),
                CreateNoteTool(store: store),
                LogHealthTool(store: store),
                QueryFinanceTool(store: store),
                QueryTasksTool(store: store),
            ],
            instructions: instructions
        )
    }

    private func handle(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            session = Self.makeSession(store: store)
            return "Let's start fresh — our conversation got long."
        case .guardrailViolation:
            return "I can't help with that one."
        default:
            return "Something went wrong. Please try again."
        }
    }

    private static let instructions = """
        You are Nexus, a concise on-device assistant inside a personal life app that \
        manages tasks, notes, health, and finances. Use the provided tools to act on the \
        user's data instead of guessing — call queryFinance or queryTasks for real numbers, \
        and createTask, createNote, or logHealth to make changes. Confirm what you did in one \
        short, friendly sentence. Keep replies under three sentences unless asked for detail.
        """

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings for full AI replies — quick commands still work here."
        case .deviceNotEligible:
            "On-device AI isn't supported on this device — quick commands still work here."
        case .modelNotReady:
            "The on-device model is still downloading — quick commands work in the meantime."
        @unknown default:
            "Full AI replies are unavailable right now — quick commands still work here."
        }
    }
}

// MARK: - Command Fallback

/// A small, explicit command handler used only when the on-device model is unavailable.
struct CommandFallback: Sendable {
    let store: NexusStore

    func reply(to input: String) async -> String {
        let lower = input.lowercased()

        if let title = Self.content(of: input, after: ["add task", "create task", "new task", "remind me to", "todo:"]) {
            let clean = Self.stripTimeWords(title)
            let due = Self.dueDate(in: lower)
            let priority = Self.priority(in: lower)
            return (try? await store.createTask(title: clean, priority: priority, dueDate: due)) ?? "I couldn't create that task."
        }

        if let body = Self.content(of: input, after: ["add note", "create note", "new note", "note:"]) {
            let (title, text) = Self.splitNote(body)
            return (try? await store.createNote(title: title, body: text)) ?? "I couldn't save that note."
        }

        if let log = Self.healthLog(in: lower) {
            return (try? await store.logHealth(metric: log.metric, value: log.value)) ?? "I couldn't log that."
        }

        if lower.contains("task") || lower.contains("todo") {
            return (try? await store.tasksOverview()) ?? "I couldn't read your tasks."
        }

        if lower.contains("spen") || lower.contains("finance") || lower.contains("money") || lower.contains("budget") {
            return (try? await store.financeSummary(period: .month)) ?? "I couldn't read your finances."
        }

        return Self.help
    }

    private static let help = """
        I can help you act on your data even without on-device AI. Try:
        • “Add task call the dentist tomorrow”
        • “Log 500 ml water” or “Log 8 hours sleep”
        • “How much did I spend this month?”
        • “What are my tasks?”
        """

    // MARK: Parsing

    private static func content(of input: String, after patterns: [String]) -> String? {
        let lower = input.lowercased()
        for pattern in patterns {
            guard let range = lower.range(of: pattern) else { continue }
            let start = input.index(input.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
            var text = String(input[start...]).trimmingCharacters(in: .whitespaces)
            for filler in ["to ", "a ", "the ", "called ", "named "] where text.lowercased().hasPrefix(filler) {
                text = String(text.dropFirst(filler.count))
            }
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func number(in text: String) -> Double? {
        guard let match = text.firstMatch(of: /(\d+\.?\d*)/) else { return nil }
        return Double(match.1)
    }

    private static func dueDate(in text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date.now
        if text.contains("today") || text.contains("tonight") {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
        }
        if text.contains("tomorrow"), let day = calendar.date(byAdding: .day, value: 1, to: now) {
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)
        }
        if text.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }
        return nil
    }

    private static func priority(in text: String) -> TaskPriority {
        if text.contains("urgent") || text.contains("asap") { return .urgent }
        if text.contains("high priority") || text.contains("important") { return .high }
        if text.contains("low priority") || text.contains("whenever") { return .low }
        return .medium
    }

    private static func stripTimeWords(_ input: String) -> String {
        var title = input
        let phrases = [" tomorrow", " today", " tonight", " next week", " high priority", " low priority", " urgent", " important"]
        for phrase in phrases {
            if let range = title.lowercased().range(of: phrase) {
                let index = title.index(title.startIndex, offsetBy: title.lowercased().distance(from: title.lowercased().startIndex, to: range.lowerBound))
                title = String(title[..<index])
            }
        }
        return title.trimmingCharacters(in: .whitespaces)
    }

    private static func splitNote(_ content: String) -> (title: String, body: String) {
        if let separator = content.firstIndex(where: { $0 == ":" || $0 == "\n" }) {
            let title = String(content[..<separator]).trimmingCharacters(in: .whitespaces)
            let body = String(content[content.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            return (title.isEmpty ? "New Note" : title, body)
        }
        return (content, "")
    }

    private static func healthLog(in text: String) -> (metric: HealthMetricType, value: Double)? {
        guard let value = number(in: text) else { return nil }
        let keywords: [(String, HealthMetricType)] = [
            ("water", .waterIntake), ("drank", .waterIntake), ("sleep", .sleep), ("slept", .sleep),
            ("step", .steps), ("walk", .steps), ("calorie", .calories), ("weigh", .weight),
            ("heart", .heartRate), ("mood", .mood), ("energy", .energy),
        ]
        for (keyword, metric) in keywords where text.contains(keyword) {
            var amount = value
            if metric == .waterIntake, text.contains("liter") || text.contains("litre") { amount = value * 1000 }
            return (metric, amount)
        }
        return nil
    }
}
