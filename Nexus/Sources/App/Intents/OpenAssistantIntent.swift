import AppIntents
import SwiftUI

struct OpenAssistantIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open AI Assistant"
    nonisolated static let description: IntentDescription = "Opens the Nexus AI Assistant"
    nonisolated static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AssistantLauncher.shared.shouldOpenAssistant = true
        return .result()
    }
}

struct NexusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAssistantIntent(),
            phrases: [
                "Open \(.applicationName) assistant",
                "Ask \(.applicationName)",
                "Open AI in \(.applicationName)",
                "Start \(.applicationName) chat"
            ],
            shortTitle: "AI Assistant",
            systemImageName: "sparkles"
        )
    }
}

@MainActor
@Observable
final class AssistantLauncher {
    static let shared = AssistantLauncher()
    var shouldOpenAssistant = false

    private init() {}
}
