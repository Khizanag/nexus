import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var type: MessageType = .text

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = .now,
        type: MessageType = .text
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.type = type
    }

    enum Role {
        case user, assistant
    }

    enum MessageType {
        case text
        case stats
        case taskList(count: Int)
        case notesSummary(count: Int)
        case financeSummary(balance: Double)
        case healthSummary
        case capabilities
        case action(icon: String, label: String)
        case taskCreated(title: String)
        case noteCreated(title: String)
        case taskCompleted(title: String)
        case taskModified(title: String)
        case healthLogged(metric: String, value: String)
    }
}
