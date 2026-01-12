import Foundation

protocol AIService {
    func sendMessage(_ message: String) async throws -> String
    func analyzeNotes(_ notes: [String]) async throws -> String
    func suggestTasks(based context: String) async throws -> [String]
    func generateInsights(for data: AIInsightRequest) async throws -> AIInsightResponse
}

struct AIInsightRequest {
    let notes: [String]
    let tasks: [String]
    let transactions: [(amount: Double, category: String)]
    let healthEntries: [(type: String, value: Double)]
}

struct AIInsightResponse {
    let summary: String
    let recommendations: [String]
    let patterns: [String]
}

final class DefaultAIService: AIService {
    private let apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1"

    init() {
        self.apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }

    func sendMessage(_ message: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            return mockResponse(for: message)
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": message,
                ]
            ],
            "system": "You are Nexus AI, a personal life assistant. Help users manage their notes, tasks, finances, and health. Be concise and helpful."
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIServiceError.requestFailed
        }

        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return result.content.first?.text ?? "I couldn't generate a response."
    }

    func analyzeNotes(_ notes: [String]) async throws -> String {
        let combined = notes.joined(separator: "\n---\n")
        let prompt = "Analyze these notes and provide key insights:\n\n\(combined)"
        return try await sendMessage(prompt)
    }

    func suggestTasks(based context: String) async throws -> [String] {
        let prompt = "Based on this context, suggest 3-5 actionable tasks:\n\n\(context)"
        let response = try await sendMessage(prompt)
        return response.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    func generateInsights(for data: AIInsightRequest) async throws -> AIInsightResponse {
        let prompt = buildInsightsPrompt(from: data)
        let response = try await sendMessage(prompt)

        return AIInsightResponse(
            summary: response,
            recommendations: [],
            patterns: []
        )
    }

    private func buildInsightsPrompt(from data: AIInsightRequest) -> String {
        var parts: [String] = ["Generate insights based on this personal data:"]

        if !data.notes.isEmpty {
            parts.append("Notes: \(data.notes.count) entries")
        }

        if !data.tasks.isEmpty {
            parts.append("Tasks: \(data.tasks.joined(separator: ", "))")
        }

        if !data.transactions.isEmpty {
            let total = data.transactions.reduce(0) { $0 + $1.amount }
            parts.append("Spending: $\(String(format: "%.2f", total)) total")
        }

        return parts.joined(separator: "\n")
    }

    private func mockResponse(for message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("task") {
            return "I can help you manage your tasks. What would you like to do?"
        } else if lowercased.contains("note") {
            return "I see you're asking about notes. Would you like me to summarize or search through them?"
        } else if lowercased.contains("finance") || lowercased.contains("money") || lowercased.contains("spend") {
            return "I can help you track your finances. What insights would you like?"
        } else if lowercased.contains("health") {
            return "Let's look at your health data. What metric interests you?"
        }

        return "I'm Nexus AI, your personal assistant. I can help with notes, tasks, finances, and health tracking. What would you like to know?"
    }
}

// MARK: - Models

private struct ClaudeResponse: Codable {
    let content: [ContentBlock]

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

enum AIServiceError: Error {
    case requestFailed
    case invalidResponse
    case apiKeyMissing
}
